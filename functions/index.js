const functions = require('firebase-functions/v1');
const admin = require("firebase-admin");
const { OAuth2Client } = require('google-auth-library');
const fetch = require('node-fetch');
const { google } = require('googleapis');
const path = require('path');
const logger = functions.logger;
const { v4: uuidv4 } = require('uuid');

const CALENDAR_ID = '[REDACTED_CALENDAR_ID]';

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

const oauth2Client = new OAuth2Client(
  '[REDACTED_CLIENT_ID]',
  '[REDACTED_CLIENT_SECRET]',
  'https://asia-east1-[REDACTED_PROJECT_ID].cloudfunctions.net/oauthCallback'
);

const calendar = google.calendar({ version: 'v3', auth: oauth2Client });

exports.oauthCallback = functions.region('asia-east1').https.onRequest(async (req, res) => {
  const { code } = req.query;

  if (!code) {
    return res.status(400).send('Missing OAuth code');
  }

  try {
    const { tokens } = await oauth2Client.getToken(code);
    oauth2Client.setCredentials(tokens);

    const email = '[REDACTED_EMAIL]';

    const userSnapshot = await admin.firestore()
      .collection('users')
      .where('email', '==', email)
      .get();

    if (userSnapshot.empty) {
      return res.status(404).send('User not found');
    }

    const userDoc = userSnapshot.docs[0];
    await userDoc.ref.update({
      googleCalendarTokens: tokens,
    });

    res.status(200).send('OAuth flow completed successfully');
  } catch (error) {
    console.error('Error completing OAuth flow:', error);
    res.status(500).send('Error completing OAuth flow');
  }
});

exports.redirectToOAuth = functions.region('asia-east1').https.onRequest((req, res) => {
  const authorizationUrl = oauth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: ['https://www.googleapis.com/auth/calendar'],
  });

  res.redirect(authorizationUrl);
});

exports.createGMeetAndInvite = functions.region('asia-east1').https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    logger.log('Handling OPTIONS preflight request');
    return res.status(204).send('');
  }

  try {
    logger.log('Received request:', { method: req.method, body: req.body });

    if (req.method !== 'POST') {
      logger.log('Invalid method:', req.method);
      return res.status(405).send({ error: 'Method not allowed, use POST' });
    }

    const { startTime, attendeeEmail, summary } = req.body;
    logger.log('Extracted parameters:', { startTime, attendeeEmail, summary });

    if (!startTime || !attendeeEmail) {
      logger.log('Missing parameters');
      return res.status(400).send({ error: 'Missing parameters' });
    }

    const start = new Date(startTime);
    if (isNaN(start.getTime())) {
      logger.log('Invalid startTime format:', startTime);
      return res.status(400).send({ error: 'Invalid startTime format' });
    }
    const end = new Date(start.getTime() + 60 * 60 * 1000);

    const userId = '[REDACTED_USER_ID]';
    const userDoc = await admin.firestore().collection('users').doc(userId).get();

    if (!userDoc.exists) {
      logger.log('User not found:', userId);
      return res.status(400).send({ error: 'User not found' });
    }

    const userData = userDoc.data();
    const tokens = userData ? userData.googleCalendarTokens : null;

    if (!tokens) {
      logger.log('Google Calendar tokens not found for user:', userId);
      return res.status(400).send({ error: 'Google Calendar tokens not found' });
    }

    oauth2Client.setCredentials(tokens);

    const event = {
      summary: summary || 'STHI Intro Meeting',
      start: { dateTime: start.toISOString(), timeZone: 'Asia/Kolkata' },
      end: { dateTime: end.toISOString(), timeZone: 'Asia/Kolkata' },
      attendees: [{ email: attendeeEmail }],
      conferenceData: {
        createRequest: { requestId: uuidv4() }
      }
    };

    const created = await calendar.events.insert({
      calendarId: CALENDAR_ID,
      requestBody: event,
      conferenceDataVersion: 1,
      sendUpdates: 'all',
    });

    const meetLink = created.data.hangoutLink;
    logger.log('Event created successfully:', { eventId: created.data.id, meetLink });

    return res.status(200).send({ eventId: created.data.id, meetLink });
  } catch (error) {
    logger.error('Error creating Google Meet event:', error);
    return res.status(500).send({ error: 'Internal server error' });
  }
});

exports.deleteGMeetEvent = functions.region('asia-east1').https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    logger.log('Handling OPTIONS preflight request');
    return res.status(204).send('');
  }

  try {
    logger.log('Received request:', { method: req.method, body: req.body });

    if (req.method !== 'POST') {
      logger.log('Invalid method:', req.method);
      return res.status(405).send({ error: 'Method not allowed, use POST' });
    }

    const { eventId } = req.body;
    logger.log('Extracted parameters:', { eventId });

    if (!eventId) {
      logger.log('Missing eventId');
      return res.status(400).send({ error: 'Missing eventId' });
    }

    if (typeof eventId !== 'string' || !eventId.trim()) {
      logger.log('Invalid eventId format:', eventId);
      return res.status(400).send({ error: 'eventId must be a non-empty string' });
    }

    const userId = '[REDACTED_USER_ID]';
    const userDoc = await admin.firestore().collection('users').doc(userId).get();

    if (!userDoc.exists) {
      logger.log('User not found:', userId);
      return res.status(400).send({ error: 'User not found' });
    }

    const userData = userDoc.data();
    const tokens = userData ? userData.googleCalendarTokens : null;

    if (!tokens) {
      logger.log('Google Calendar tokens not found for user:', userId);
      return res.status(400).send({ error: 'Google Calendar tokens not found' });
    }

    oauth2Client.setCredentials(tokens);

    await calendar.events.delete({
      calendarId: CALENDAR_ID,
      eventId,
      sendUpdates: 'all',
    });

    logger.log('Event deleted successfully:', { eventId });

    return res.status(200).send({ success: true, eventId });
  } catch (error) {
    logger.error('Error deleting Google Meet event:', error);
    return res.status(500).send({ error: 'Internal server error' });
  }
});

exports.fetchBusySlots = functions.region('asia-east1').https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    logger.log('Handling OPTIONS preflight request');
    return res.status(204).send('');
  }

  try {
    logger.log('Received request:', { method: req.method, body: req.body });
    if (req.method !== 'POST') {
      logger.log('Invalid method:', req.method);
      return res.status(405).send({ error: 'Method not allowed, use POST' });
    }

    const { startDate, endDate } = req.body;
    logger.log('Extracted parameters:', { startDate, endDate });

    if (!startDate || !endDate) {
      logger.log('Missing startDate or endDate');
      return res.status(400).send({ error: 'Missing startDate or endDate' });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      logger.log('Invalid date format:', { startDate, endDate });
      return res.status(400).send({ error: 'Invalid date format' });
    }

    const userId = '[REDACTED_USER_ID]';
    const userDoc = await admin.firestore().collection('users').doc(userId).get();

    if (!userDoc.exists) {
      logger.log('User not found:', userId);
      return res.status(400).send({ error: 'User not found' });
    }

    const userData = userDoc.data();
    const tokens = userData ? userData.googleCalendarTokens : null;

    if (!tokens) {
      logger.log('Google Calendar tokens not found for user:', userId);
      return res.status(400).send({ error: 'Google Calendar tokens not found' });
    }

    oauth2Client.setCredentials(tokens);

    const response = await calendar.freebusy.query({
      requestBody: {
        timeMin: start.toISOString(),
        timeMax: end.toISOString(),
        timeZone: 'Asia/Kolkata',
        items: [{ id: CALENDAR_ID }],
      },
    });

    const busyTimes = response.data.calendars[CALENDAR_ID]?.busy || [];
    logger.log('Fetched busy times:', busyTimes);

    res.status(200).send({ busyTimes });
  } catch (error) {
    logger.error('Error fetching busy slots:', error);
    res.status(500).send({ error: 'Internal server error' });
  }
});

exports.proxy = functions.region('asia-east1').https.onRequest(async (req, res) => {
  const allowedOrigins = [];
  const origin = req.get('origin') || '';
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  console.log('Raw query:', JSON.stringify(req.query));

  const url = req.query.url;
  if (!url) {
    console.error('Missing URL parameter');
    return res.status(400).send(JSON.stringify({ error_message: 'URL parameter is required' }));
  }

  const decodedUrl = decodeURIComponent(url);
  const validEndpoints = [
    'https://maps.googleapis.com/maps/api/place/autocomplete/json',
    'https://maps.googleapis.com/maps/api/place/details/json',
  ];
  if (!validEndpoints.some(endpoint => decodedUrl.startsWith(endpoint))) {
    console.error('Invalid API URL:', decodedUrl);
    return res.status(400).send(JSON.stringify({ error_message: 'Invalid API URL. Only Google Places Autocomplete and Details endpoints are supported.' }));
  }
  console.log('Decoded URL:', decodedUrl);

  const urlObj = new URL(decodedUrl);
  const endpoint = urlObj.pathname;
  const params = urlObj.searchParams;

  if (endpoint.includes('autocomplete/json')) {
    if (!params.has('key') || !params.has('input')) {
      console.error('Missing required parameters for autocomplete:', { key: params.has('key'), input: params.has('input') });
      return res.status(400).send(JSON.stringify({ error_message: 'Missing required parameters: key and input are required for autocomplete.' }));
    }
  } else if (endpoint.includes('details/json')) {
    if (!params.has('key') || !params.has('placeid')) {
      console.error('Missing required parameters for details:', { key: params.has('key'), placeid: params.has('placeid') });
      return res.status(400).send(JSON.stringify({ error_message: 'Missing required parameters: key and placeid are required for place details.' }));
    }
  }

  try {
    console.log('Proxying request to:', decodedUrl);

    const response = await fetch(decodedUrl, {
      method: 'GET',
      timeout: 15000,
    });

    const body = await response.text();
    let jsonBody;
    try {
      jsonBody = JSON.parse(body);
    } catch (e) {
      console.error('Invalid JSON response:', body);
      throw new Error('Invalid response format from Google Places API');
    }

    if (!response.ok || jsonBody.status === 'REQUEST_DENIED' || jsonBody.status === 'OVER_QUERY_LIMIT') {
      const errorMessage = jsonBody.error_message || `HTTP error! Status: ${response.status}`;
      console.error('API error:', errorMessage, 'Response:', jsonBody);
      return res.status(response.status || 500).send(JSON.stringify({ error_message: errorMessage }));
    }

    const safeHeaders = {};
    for (const [key, value] of response.headers.entries()) {
      if (typeof value === 'string' && /^[\x20-\x7E]*$/.test(value)) {
        safeHeaders[key] = value;
      } else {
        console.warn(`Skipping invalid header: ${key}=${value}`);
      }
    }
    console.log('Sanitized headers:', safeHeaders);

    res.status(response.status).set(safeHeaders).send(body);
  } catch (error) {
    console.error('Error forwarding request:', error.message, error.stack, 'URL:', decodedUrl);
    res.status(500).send(JSON.stringify({ error_message: error.message }));
  }
});

exports.placeDetailsProxy = functions.region('asia-east1').https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  console.log('Raw query:', JSON.stringify(req.query));

  const { place_id, key } = req.query;
  if (!place_id || !key) {
    console.error('Missing parameters:', { place_id, key });
    return res.status(400).json({ error_message: 'place_id and key are required' });
  }

  const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${encodeURIComponent(place_id)}&key=${encodeURIComponent(key)}&fields=place_id,name,formatted_address,geometry,formatted_phone_number,international_phone_number,website,type`;

  try {
    console.log('Proxying request to:', url);

    const response = await fetch(url, {
      method: 'GET',
      timeout: 10000,
    });

    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }

    const body = await response.text();
    res.status(response.status).send(body);
  } catch (error) {
    console.error('Error forwarding request:', error.message, error.stack);
    res.status(500).json({ error_message: error.message });
  }
});

async function saveWithRetry(docRef, data, retries = 3, delay = 2000) {
  for (let i = 0; i < retries; i++) {
    try {
      await docRef.set(data);
      return;
    } catch (err) {
      if (i === retries - 1) throw err;
      console.log(`Retrying (${i + 1}/${retries}) due to error:`, err);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

exports.createDocOnNewUser = functions.region('asia-east1').auth.user()
  .onCreate(async (user) => {
    const userId = user.uid;
    const email = user.email || "";
    const phoneNumber = user.phoneNumber || null;
    let displayName = user.displayName || "";

    const providerData = user.providerData || [];
    const platform = providerData.length > 0 ? providerData[0].providerId : "unknown";

    const userDoc = {
      user_id: userId,
      created_timestamp: admin.firestore.FieldValue.serverTimestamp(),
      last_updated_timestamp: admin.firestore.FieldValue.serverTimestamp(),
      display_name: displayName,
      email: email,
      phone_number: phoneNumber,
      auth_platform: platform,
      requested_places: [],
      appointments: [],
    };

    try {
      await saveWithRetry(db.collection("users").doc(userId), userDoc);
      console.log(`User document created for user ${userId}`);
    } catch (err) {
      console.error(`Error creating user document for ${userId} after retries:`, err);
      throw new Error("Failed to create user document");
    }
  });