import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http show post;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sitesathi/features/web/domain/entities/requested_place_details.dart';
import 'package:sitesathi/features/web/presentation/cubit/webapp_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

// Cache TextStyles to prevent GoogleFonts stack overflow
class AppTextStyles {
  static TextStyle interRegular(double fontSize) =>
      GoogleFonts.inter(fontSize: fontSize, fontWeight: FontWeight.w400);
  static TextStyle interBold(double fontSize) =>
      GoogleFonts.inter(fontSize: fontSize, fontWeight: FontWeight.w700);
  static TextStyle interSemiBold(double fontSize) =>
      GoogleFonts.inter(fontSize: fontSize, fontWeight: FontWeight.w600);
  static TextStyle interMedium(double fontSize) =>
      GoogleFonts.inter(fontSize: fontSize, fontWeight: FontWeight.w500);
}

class PlaceCard extends StatefulWidget {
  final RequestedPlaceDetails placeDetails;
  final double? cardHeight;
  final double? cardWidth;
  final bool awaitConfirm;
  final VoidCallback? onClose;
  final bool isLoading;

  const PlaceCard({
    super.key,
    required this.placeDetails,
    this.cardHeight,
    this.cardWidth,
    this.awaitConfirm = false,
    this.onClose,
    required this.isLoading,
  });

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  DateTime? selectedDate;
  TimeOfDay? selectedTimeOfDay;
  String selectedRole = 'Vendor';
  Set<Map<String, DateTime>> busySlots = {};
  bool isConfirming = false;
  Future<Set<Map<String, DateTime>>>? _busySlotsFuture;
  DateTime? _lastFetchedDate;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '> PlaceCard initState for placeId: ${widget.placeDetails.placeId}',
    );
    debugPrint('> nextAppointment: ${widget.placeDetails.nextAppointment}');
    final appointment = widget.placeDetails.nextAppointment;
    final appointmentDate = appointment?['booked_slot']?.toDate();
    final isMissed =
        appointmentDate != null && appointmentDate.isBefore(DateTime.now());
    if (widget.awaitConfirm || isMissed) {
      selectedDate = DateTime.now().add(const Duration(days: 1));
      _lastFetchedDate = selectedDate;
      _busySlotsFuture = _fetchBusySlots();
      debugPrint(
        '> Initialized _busySlotsFuture in initState for date: $selectedDate',
      );
    }
  }

  @override
  void didUpdateWidget(covariant PlaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final appointment = widget.placeDetails.nextAppointment;
    final oldAppointment = oldWidget.placeDetails.nextAppointment;
    final appointmentDate = appointment?['booked_slot']?.toDate();
    final oldAppointmentDate = oldAppointment?['booked_slot']?.toDate();
    final isMissed =
        appointmentDate != null && appointmentDate.isBefore(DateTime.now());
    // Reinitialize only if placeId, awaitConfirm, or booked_slot changes
    if (oldWidget.placeDetails.placeId != widget.placeDetails.placeId ||
        oldWidget.awaitConfirm != widget.awaitConfirm ||
        oldAppointmentDate != appointmentDate ||
        (isMissed && !oldWidget.isLoading)) {
      debugPrint(
        '> didUpdateWidget for placeId: ${widget.placeDetails.placeId}, Reinitializing due to: '
        'placeIdChanged: ${oldWidget.placeDetails.placeId != widget.placeDetails.placeId}, '
        'awaitConfirmChanged: ${oldWidget.awaitConfirm != widget.awaitConfirm}, '
        'appointmentDateChanged: $oldAppointmentDate != $appointmentDate, '
        'isMissed: $isMissed, oldIsLoading: ${oldWidget.isLoading}',
      );
      // Only reset if selectedDate changes or is null
      if (selectedDate == null || selectedDate != _lastFetchedDate) {
        selectedDate = DateTime.now().add(const Duration(days: 1));
        _lastFetchedDate = selectedDate;
        _busySlotsFuture = _fetchBusySlots();
        debugPrint(
          '> Reset _busySlotsFuture in didUpdateWidget for date: $selectedDate',
        );
      }
    }
  }

  Future<Set<Map<String, DateTime>>> _fetchBusySlots() async {
    try {
      debugPrint(
        '> Initiating _fetchBusySlots for date: $selectedDate, future: ${_busySlotsFuture.hashCode}',
      );
      final url = Uri.parse(
        'https://asia-east1-sitesathi-4f0e4.cloudfunctions.net/fetchBusySlots',
      );
      final nowUtc = DateTime.now().toUtc();
      final endUtc = nowUtc.add(const Duration(days: 30));
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'startDate': nowUtc.toIso8601String(),
          'endDate': endUtc.toIso8601String(),
        }),
      );

      debugPrint(
        '> fetchBusySlots response: ${response.statusCode} ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['busyTimes'] is List) {
          final List<dynamic> busyTimes = data['busyTimes'];
          final slots =
              busyTimes
                  .map((slot) {
                    try {
                      final start = DateTime.parse(slot['start']).toLocal();
                      final end = DateTime.parse(slot['end']).toLocal();
                      return <String, DateTime>{'start': start, 'end': end};
                    } catch (e) {
                      debugPrint('> Error parsing slot: $slot, error: $e');
                      return <String, DateTime>{};
                    }
                  })
                  .where((slot) => slot.isNotEmpty)
                  .cast<Map<String, DateTime>>()
                  .toSet();
          debugPrint('> Parsed busy slots: $slots');
          return slots;
        }
        debugPrint('> No busyTimes in response');
        return {};
      } else {
        throw Exception(
          'Failed to fetch busy slots (status ${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error from placeCard _fetchBusySlots: $e');
      rethrow;
    }
  }

  Future<void> _reschedule() async {
    if (selectedDate == null || selectedTimeOfDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid date and time slot'),
        ),
      );
      return;
    }

    final newAppointmentSlot = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTimeOfDay!.hour,
      selectedTimeOfDay!.minute,
    );

    setState(() => isConfirming = true);
    try {
      debugPrint(
        'Rescheduling appointment for place: ${widget.placeDetails.placeName}',
      );
      await context.read<WebappCubit>().rescheduleAppointment(
        widget.placeDetails.placeId,
        newAppointmentSlot,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment rescheduled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reset local state to trigger reload
        setState(() {
          selectedDate = DateTime.now().add(const Duration(days: 1));
          selectedTimeOfDay = null;
          busySlots.clear();
          _lastFetchedDate = selectedDate;
          _busySlotsFuture = _fetchBusySlots();
        });
      }
    } catch (e) {
      debugPrint('Error in _reschedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => isConfirming = false);
      }
    }
  }

  Future<void> _confirmPlace() async {
    if (selectedDate == null || selectedTimeOfDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid date and time slot'),
        ),
      );
      return;
    }

    final appointmentSlot = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTimeOfDay!.hour,
      selectedTimeOfDay!.minute,
    );

    setState(() => isConfirming = true);
    try {
      debugPrint('Confirming place with role: $selectedRole');
      await context.read<WebappCubit>().confirmPlace(
        widget.placeDetails,
        selectedRole,
        appointmentSlot,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment scheduled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _confirmPlace: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => isConfirming = false);
      }
    }
  }

  Widget _shimmerContainer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = widget.placeDetails.status == 'verified';
    final appointment = widget.placeDetails.nextAppointment;
    final appointmentDate = appointment?['booked_slot']?.toDate();
    final isMissed =
        appointmentDate != null && appointmentDate.isBefore(DateTime.now());
    final screenSize = MediaQuery.of(context).size;
    final horizontalPadding =
        screenSize.width < 360
            ? 8.0
            : screenSize.width < 600
            ? 16.0
            : 32.0;
    final isWide = screenSize.width > screenSize.height;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            isWide ? CrossAxisAlignment.center : CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenSize.width < 360 ? 8.0 : 16.0,
              vertical: 12,
            ),
            height: widget.cardHeight ?? (screenSize.height < 600 ? 320 : 360),
            constraints: BoxConstraints(
              maxWidth: 480,
              minWidth:
                  screenSize.width < 360
                      ? screenSize.width - (horizontalPadding * 2)
                      : 0,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(245),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                isVerified
                    ? _verifiedPlaceDetails()
                    : (widget.awaitConfirm
                        ? _awaitingConfirmation()
                        : (isMissed
                            ? _buildMissed()
                            : _requestedPlaceDetails())),
          ),
          const SizedBox(height: 12),
          if (!widget.isLoading && !isConfirming)
            TextButton(
              onPressed: widget.onClose,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(25),
                minimumSize: const Size(48, 48),
                maximumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                splashFactory: NoSplash.splashFactory,
              ),
              child: const Center(
                child: Icon(Icons.close, size: 16, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

  Widget _verifiedPlaceDetails() {
    final screenSize = MediaQuery.of(context).size;
    final fontSize = screenSize.width < 360 ? 14.0 : 16.0;
    final titleFontSize = screenSize.width < 360 ? 16.0 : 18.0;

    return widget.isLoading
        ? _shimmerContainer()
        : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verified',
              style: AppTextStyles.interBold(
                titleFontSize,
              ).copyWith(color: Colors.green),
            ),
            const SizedBox(height: 6),
            Text(
              widget.placeDetails.placeName ?? 'N/A',
              style: AppTextStyles.interBold(fontSize),
            ),
            const SizedBox(height: 4),
            Text(
              widget.placeDetails.formattedAddress ?? 'N/A',
              style: AppTextStyles.interRegular(fontSize),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        );
  }

  Widget _awaitingConfirmation() {
    final List<TimeOfDay> dailySlots = [
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 13, minute: 0),
      const TimeOfDay(hour: 15, minute: 0),
      const TimeOfDay(hour: 20, minute: 30),
    ];

    selectedDate ??= DateTime.now().add(const Duration(days: 1));

    DateTime slotStart(TimeOfDay tod) => DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      tod.hour,
      tod.minute,
    );

    DateTime slotEnd(TimeOfDay tod) =>
        slotStart(tod).add(const Duration(hours: 1));

    bool isBusySlot(TimeOfDay tod) {
      final slotStartTime = slotStart(tod);
      final slotEndTime = slotEnd(tod);

      for (var busy in busySlots) {
        final busyStart = busy['start']!;
        final busyEnd = busy['end']!;
        if (slotStartTime.isBefore(busyEnd) &&
            busyStart.isBefore(slotEndTime)) {
          return true;
        }
      }
      return false;
    }

    final screenSize = MediaQuery.of(context).size;
    final childAspectRatio =
        screenSize.width < 360
            ? 2.0
            : screenSize.width < 400
            ? 2.5
            : 3.8;
    final titleFontSize = screenSize.width < 360 ? 18.0 : 22.0;
    final timeFontSize = screenSize.width < 360 ? 12.0 : 14.0;
    final iconSize = screenSize.width < 360 ? 14.0 : 18.0;

    return SizedBox(
      height: widget.cardHeight ?? (screenSize.height < 600 ? 320 : 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  "Review and Confirm",
                  style: AppTextStyles.interSemiBold(
                    titleFontSize,
                  ).copyWith(fontSize: titleFontSize),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          widget.isLoading && !isConfirming
              ? _shimmerContainer()
              : Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      widget.placeDetails.placeName ?? 'N/A',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: AppTextStyles.interSemiBold(
                        timeFontSize,
                      ).copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.placeDetails.formattedAddress ?? 'N/A',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: AppTextStyles.interRegular(
                        timeFontSize,
                      ).copyWith(color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Pick a Time (IST)',
                  style: AppTextStyles.interSemiBold(timeFontSize),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message:
                    "Select a time for a quick call to discuss your business. All times are in Indian Standard Time (IST).",
                child: Icon(
                  Icons.info_outline,
                  color: Colors.black.withAlpha(200),
                  size: iconSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: null,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width < 360 ? 2.0 : 6.0,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.black.withAlpha(40)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_sharp),
                    iconSize: iconSize,
                    color:
                        (selectedDate!.day ==
                                DateTime.now().add(const Duration(days: 1)).day)
                            ? Colors.transparent
                            : null,
                    onPressed:
                         widget.isLoading || isConfirming ? () {} : (selectedDate!.day ==
                                DateTime.now().add(const Duration(days: 1)).day)
                            ? null
                            : () {
                              setState(() {
                                selectedDate = selectedDate!.subtract(
                                  const Duration(days: 1),
                                );
                                selectedTimeOfDay = null;
                                if (selectedDate != _lastFetchedDate) {
                                  _lastFetchedDate = selectedDate;
                                  _busySlotsFuture = _fetchBusySlots();
                                  debugPrint(
                                    '> Updated _busySlotsFuture in _awaitingConfirmation for date: $selectedDate',
                                  );
                                }
                              });
                            },
                  ),
                  Text(
                    '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                    style: AppTextStyles.interRegular(timeFontSize).copyWith(
                      color: Colors.black.withAlpha(140),
                      fontSize: timeFontSize,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_sharp),
                    iconSize: iconSize,
                    onPressed: widget.isLoading || isConfirming ? () {} : () {
                      setState(() {
                        selectedDate = selectedDate!.add(
                          const Duration(days: 1),
                        );
                        selectedTimeOfDay = null;
                        if (selectedDate != _lastFetchedDate) {
                          _lastFetchedDate = selectedDate;
                          _busySlotsFuture = _fetchBusySlots();
                          debugPrint(
                            '> Updated _busySlotsFuture in _awaitingConfirmation for date: $selectedDate',
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<Set<Map<String, DateTime>>>(
              future: _busySlotsFuture,
              builder: (context, snapshot) {
                debugPrint(
                  '> FutureBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}, future: ${_busySlotsFuture.hashCode}',
                );
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: screenSize.width < 360 ? 1 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder:
                        (context, index) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load slots: ${snapshot.error}',
                      style: AppTextStyles.interRegular(
                        timeFontSize,
                      ).copyWith(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                } else {
                  busySlots = snapshot.data ?? {};
                  debugPrint('> Updated busySlots: $busySlots');
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dailySlots.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: screenSize.width < 360 ? 1 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, i) {
                      final tod = dailySlots[i];
                      final label = tod.format(context);
                      final busy = isBusySlot(tod);
                      return TextButton(
                        onPressed:
                            (busy || widget.isLoading)
                                ? null
                                : () => setState(() => selectedTimeOfDay = tod),
                        style: TextButton.styleFrom(
                          backgroundColor:
                              selectedTimeOfDay == tod
                                  ? Colors.black
                                  : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color:
                                  busy
                                      ? Colors.grey.withAlpha(100)
                                      : Colors.black.withAlpha(40),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width < 360 ? 2.0 : 6.0,
                          ),
                        ),
                        child: Tooltip(
                          message:
                              busy
                                  ? 'This slot is booked.'
                                  : 'Available in IST',
                          child: Text(
                            label,
                            style: AppTextStyles.interMedium(
                              timeFontSize,
                            ).copyWith(
                              fontSize: timeFontSize,
                              color:
                                  busy
                                      ? Colors.grey.withAlpha(100)
                                      : (selectedTimeOfDay == tod
                                          ? Colors.white
                                          : Colors.black.withAlpha(140)),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          ConfirmButton(
            selectedDate: selectedDate,
            selectedTimeOfDay: selectedTimeOfDay,
            onConfirm: _confirmPlace,
            label: 'Confirm',
          ),
        ],
      ),
    );
  }

  Widget _requestedPlaceDetails() {
    final appointment = widget.placeDetails.nextAppointment;
    final lastUpdateTimestamp =
        widget.placeDetails.lastInteractionTimestamp.toDate();
    final appointmentDate =
        appointment != null && appointment['booked_slot'] is Timestamp
            ? (appointment['booked_slot'] as Timestamp).toDate()
            : null;
    final meetLink = appointment?['meet_link'] as String?;

    final screenSize = MediaQuery.of(context).size;
    final smallScreen = screenSize.width < 360;
    final fontSize = smallScreen ? 12.0 : 14.0;
    final titleFontSize = smallScreen ? 14.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isLoading)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: 120,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(width: 80, height: 14, color: Colors.white),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TextButton(
                  onPressed: () {
                    // TODO: Add logic to handle status button tap
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withAlpha(100),
                    padding: EdgeInsets.symmetric(
                      horizontal: smallScreen ? 8.0 : 16.0,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: Text( // TODO : HANDLE STATUS
                    widget.placeDetails.status == 'awaiting_appointment'
                        ? 'Verification Pending'
                        : 'Other',
                    style: AppTextStyles.interRegular(
                      fontSize,
                    ).copyWith(color: Colors.white, fontSize: fontSize),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  DateFormat('MMM d, y').format(lastUpdateTimestamp),
                  style: AppTextStyles.interBold(fontSize).copyWith(
                    color: Colors.black.withAlpha(100),
                    fontSize: smallScreen ? 10.0 : 12.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        widget.isLoading && !isConfirming
            ? _shimmerContainer()
            : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.placeDetails.placeName ?? 'N/A',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: AppTextStyles.interSemiBold(
                      titleFontSize,
                    ).copyWith(color: Colors.white, fontSize: titleFontSize),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.placeDetails.formattedAddress ?? 'N/A',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: AppTextStyles.interRegular(
                      fontSize,
                    ).copyWith(color: Colors.grey.shade400, fontSize: fontSize),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 12),
        if (widget.isLoading)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 40,
                        height: 16,
                        color: Colors.white,
                      ),
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 120,
                        height: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 40,
                        height: 16,
                        color: Colors.white,
                      ),
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 80,
                        height: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              if (appointmentDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Slot',
                        style: AppTextStyles.interRegular(
                          fontSize,
                        ).copyWith(fontSize: fontSize),
                      ),
                      Flexible(
                        child: Text(
                          DateFormat(
                            'h:mm a, MMM d, y',
                          ).format(appointmentDate),
                          style: AppTextStyles.interBold(
                            fontSize,
                          ).copyWith(fontSize: fontSize),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              if (appointment != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Role',
                        style: AppTextStyles.interRegular(
                          fontSize,
                        ).copyWith(fontSize: fontSize),
                      ),
                      Text(
                        appointment['selected_role'] ?? 'N/A',
                        style: AppTextStyles.interBold(
                          fontSize,
                        ).copyWith(fontSize: fontSize),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const Spacer(),
        if (!widget.isLoading) ...[
          GoogleMeetDetails(
            appointmentDate: appointmentDate,
            lastUpdateTimestamp: lastUpdateTimestamp,
            meetLink: meetLink,
            onReschedule: _reschedule,
            fontSize: fontSize,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final placeId = widget.placeDetails.placeId;
              final mapsUri = Uri.parse(
                'https://www.google.com/maps/place/?q=place_id:$placeId',
              );
              if (await canLaunchUrl(mapsUri)) {
                await launchUrl(mapsUri);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot launch Google Maps')),
                );
              }
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'View on Google Maps',
                  style: AppTextStyles.interRegular(
                    fontSize,
                  ).copyWith(fontSize: fontSize, color: Colors.black),
                ),
                Icon(
                  Icons.map,
                  size: smallScreen ? 16 : 18,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget GoogleMeetDetails({
    required DateTime? appointmentDate,
    required DateTime lastUpdateTimestamp,
    required String? meetLink,
    required VoidCallback onReschedule,
    required double fontSize,
  }) {
    final isMissed =
        appointmentDate != null && appointmentDate.isBefore(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meetLink != null && !isMissed)
          TextButton(
            onPressed: () async {
              final meetUri = Uri.parse(meetLink);
              if (await canLaunchUrl(meetUri)) {
                await launchUrl(meetUri);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot launch Google Meet')),
                );
              }
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Go to Google Meet',
                  style: AppTextStyles.interRegular(
                    fontSize,
                  ).copyWith(color: Colors.white, fontSize: fontSize),
                ),
                Icon(Icons.launch, color: Colors.white, size: fontSize),
              ],
            ),
          ),
        if (isMissed)
          TextButton(
            onPressed: onReschedule,
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reschedule Appointment',
                  style: AppTextStyles.interRegular(
                    fontSize,
                  ).copyWith(color: Colors.white, fontSize: fontSize),
                ),
                Icon(Icons.calendar_today, color: Colors.white, size: fontSize),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMissed() {
    final List<TimeOfDay> dailySlots = [
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 13, minute: 0),
      const TimeOfDay(hour: 15, minute: 0),
      const TimeOfDay(hour: 20, minute: 30),
    ];

    selectedDate ??= DateTime.now().add(const Duration(days: 1));

    // Only initialize _busySlotsFuture if not already set
    if (_busySlotsFuture == null && _lastFetchedDate != selectedDate) {
      _lastFetchedDate = selectedDate;
      _busySlotsFuture = _fetchBusySlots();
      debugPrint(
        '> Initialized _busySlotsFuture in _buildMissed for date: $selectedDate',
      );
    }

    DateTime slotStart(TimeOfDay tod) => DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      tod.hour,
      tod.minute,
    );

    DateTime slotEnd(TimeOfDay tod) =>
        slotStart(tod).add(const Duration(hours: 1));

    bool isBusySlot(TimeOfDay tod) {
      final slotStartTime = slotStart(tod);
      final slotEndTime = slotEnd(tod);

      for (var busy in busySlots) {
        final busyStart = busy['start']!;
        final busyEnd = busy['end']!;
        if (slotStartTime.isBefore(busyEnd) &&
            busyStart.isBefore(slotEndTime)) {
          return true;
        }
      }
      return false;
    }

    final screenSize = MediaQuery.of(context).size;
    final childAspectRatio =
        screenSize.width < 360
            ? 2.0
            : screenSize.width < 400
            ? 2.5
            : 3.8;
    final titleFontSize = screenSize.width < 360 ? 18.0 : 22.0;
    final timeFontSize = screenSize.width < 360 ? 12.0 : 14.0;
    final iconSize = screenSize.width < 360 ? 14.0 : 18.0;
    final lastAppointment = widget.placeDetails.nextAppointment;

    return SizedBox(
      height: widget.cardHeight ?? (screenSize.height < 600 ? 320 : 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  "Reschedule Appointment",
                  style: AppTextStyles.interSemiBold(
                    titleFontSize,
                  ).copyWith(fontSize: titleFontSize),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          widget.isLoading && !isConfirming
              ? _shimmerContainer()
              : Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      widget.placeDetails.placeName ?? 'N/A',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: AppTextStyles.interSemiBold(
                        timeFontSize,
                      ).copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.placeDetails.formattedAddress ?? 'N/A',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: AppTextStyles.interRegular(
                        timeFontSize,
                      ).copyWith(color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              if (widget.isLoading)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: 40,
                          height: 16,
                          color: Colors.white,
                        ),
                      ),
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: 120,
                          height: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: 40,
                          height: 16,
                          color: Colors.white,
                        ),
                      ),
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: 80,
                          height: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                if (lastAppointment != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Previous Slot',
                          style: AppTextStyles.interRegular(
                            timeFontSize,
                          ).copyWith(fontSize: timeFontSize),
                        ),
                        Flexible(
                          child: Text(
                            DateFormat(
                              'h:mm a, MMM d, y',
                            ).format((lastAppointment['booked_slot'] as Timestamp).toDate()),
                            style: AppTextStyles.interBold(
                              timeFontSize,
                            ).copyWith(fontSize: timeFontSize),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (lastAppointment != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Role',
                          style: AppTextStyles.interRegular(
                            timeFontSize,
                          ).copyWith(fontSize: timeFontSize),
                        ),
                        Text(
                          lastAppointment['selected_role'] ?? 'N/A',
                          style: AppTextStyles.interBold(
                            timeFontSize,
                          ).copyWith(fontSize: timeFontSize),
                        ),
                      ],
                    ),
                  ),
                  if (lastAppointment != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: AppTextStyles.interRegular(
                            timeFontSize,
                          ).copyWith(fontSize: timeFontSize),
                        ),
                        Text(
                          'MISSED',
                          style: AppTextStyles.interBold(
                            timeFontSize,
                          ).copyWith(fontSize: timeFontSize, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Pick a Time (IST)',
                  style: AppTextStyles.interSemiBold(timeFontSize),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message:
                    "Select a time for a quick call to discuss your business. All times are in Indian Standard Time (IST).",
                child: Icon(
                  Icons.info_outline,
                  color: Colors.black.withAlpha(200),
                  size: iconSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: null,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width < 360 ? 2.0 : 6.0,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.black.withAlpha(40)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_sharp,
                      color:
                          (selectedDate!.day ==
                                  DateTime.now()
                                      .add(const Duration(days: 1))
                                      .day)
                              ? Colors.transparent
                              : null,
                    ),
                    iconSize: iconSize,

                    onPressed:
                        (selectedDate!.day ==
                                DateTime.now().add(const Duration(days: 1)).day)
                            ? null
                            : () {
                              setState(() {
                                selectedDate = selectedDate!.subtract(
                                  const Duration(days: 1),
                                );
                                selectedTimeOfDay = null;
                                if (selectedDate != _lastFetchedDate) {
                                  _lastFetchedDate = selectedDate;
                                  _busySlotsFuture = _fetchBusySlots();
                                  debugPrint(
                                    '> Updated _busySlotsFuture in _buildMissed for date: $selectedDate',
                                  );
                                }
                              });
                            },
                  ),
                  Text(
                    '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                    style: AppTextStyles.interRegular(timeFontSize).copyWith(
                      color: Colors.black.withAlpha(140),
                      fontSize: timeFontSize,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_sharp),
                    iconSize: iconSize,
                    onPressed: () {
                      setState(() {
                        selectedDate = selectedDate!.add(
                          const Duration(days: 1),
                        );
                        selectedTimeOfDay = null;
                        if (selectedDate != _lastFetchedDate) {
                          _lastFetchedDate = selectedDate;
                          _busySlotsFuture = _fetchBusySlots();
                          debugPrint(
                            '> Updated _busySlotsFuture in _buildMissed for date: $selectedDate',
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<Set<Map<String, DateTime>>>(
              future: _busySlotsFuture,
              builder: (context, snapshot) {
                debugPrint(
                  '> FutureBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}, future: ${_busySlotsFuture.hashCode}',
                );
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: screenSize.width < 360 ? 1 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder:
                        (context, index) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load slots: ${snapshot.error}',
                      style: AppTextStyles.interRegular(
                        timeFontSize,
                      ).copyWith(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                } else {
                  busySlots = snapshot.data ?? {};
                  debugPrint('> Updated busySlots: $busySlots');
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dailySlots.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: screenSize.width < 360 ? 1 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, i) {
                      final tod = dailySlots[i];
                      final label = tod.format(context);
                      final busy = isBusySlot(tod);
                      return TextButton(
                        onPressed:
                            (busy || widget.isLoading)
                                ? null
                                : () => setState(() => selectedTimeOfDay = tod),
                        style: TextButton.styleFrom(
                          backgroundColor:
                              selectedTimeOfDay == tod
                                  ? Colors.black
                                  : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color:
                                  busy
                                      ? Colors.grey.withAlpha(100)
                                      : Colors.black.withAlpha(40),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width < 360 ? 2.0 : 6.0,
                          ),
                        ),
                        child: Tooltip(
                          message:
                              busy
                                  ? 'This slot is booked.'
                                  : 'Available in IST',
                          child: Text(
                            label,
                            style: AppTextStyles.interMedium(
                              timeFontSize,
                            ).copyWith(
                              fontSize: timeFontSize,
                              color:
                                  busy
                                      ? Colors.grey.withAlpha(100)
                                      : (selectedTimeOfDay == tod
                                          ? Colors.white
                                          : Colors.black.withAlpha(140)),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          ConfirmButton(
            selectedDate: selectedDate,
            selectedTimeOfDay: selectedTimeOfDay,
            onConfirm: _reschedule,
            label: 'Reschedule',
          ),
        ],
      ),
    );
  }
}

class ConfirmButton extends StatefulWidget {
  final DateTime? selectedDate;
  final TimeOfDay? selectedTimeOfDay;
  final Future<void> Function() onConfirm;
  final String label;

  const ConfirmButton({
    super.key,
    required this.selectedDate,
    required this.selectedTimeOfDay,
    required this.onConfirm,
    this.label = 'Confirm',
  });

  @override
  State<ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<ConfirmButton> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled =
        widget.selectedDate != null && widget.selectedTimeOfDay != null;
    final screenSize = MediaQuery.of(context).size;
    final fontSize = screenSize.width < 360 ? 16.0 : 18.0;

    return TextButton(
      onPressed:
          isEnabled && !isLoading
              ? () async {
                setState(() => isLoading = true);
                try {
                  await widget.onConfirm();
                } catch (e) {
                  // Error handled in _confirmPlace or _reschedule
                } finally {
                  if (mounted) {
                    setState(() => isLoading = false);
                  }
                }
              }
              : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: isEnabled ? Colors.black : Colors.grey.shade400,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child:
          isLoading
              ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeCap: StrokeCap.round,
                  strokeWidth: 2,
                ),
              )
              : Text(
                widget.label,
                style: AppTextStyles.interRegular(
                  fontSize,
                ).copyWith(color: Colors.white, fontSize: fontSize),
              ),
    );
  }
}
