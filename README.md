CanT — Can Train with Your Mate anywhere

A social sports platform connecting people through local events, communities, and sport-based matchmaking.


🧠 Product Background
As a Product Manager, I identified a clear gap in the German market: no dedicated platform existed for spontaneous, pickup sports with strangers. Existing solutions like WhatsApp groups were fragmented and unscalable.
I validated this opportunity through:

An existing WhatsApp community of 200–500 active sports enthusiasts in Karlsruhe
Competitive analysis revealing that Playo — the closest competitor, winner of a German startup award in 2019 — never entered the German market
Direct user interviews confirming friction in discovering and organizing local sports events

To move fast and validate the concept, I took an unconventional approach: I built the MVP myself, end-to-end, using Flutter and Firebase.

📱 Product Overview
CanT is a mobile application that allows users to:

Discover and join local sports events on an interactive map
Create events with location, time, capacity, and optional photos
Match with nearby sport mates via a Tinder-style swipe system
Chat directly with matches
Join sport-specific communities (Football, Basketball, Bouldering, etc.)
Receive real-time notifications for matches, messages, and waitlist updates


🎯 Key Product Decisions
DecisionRationaleFlutter over React NativeSingle codebase for Android + iOS, faster iterationFirebase over custom backendZero DevOps overhead, real-time sync out of the boxSwipe-based matchingLowers barrier to connecting with strangers vs. cold messagingCommunity forums per sportBuilds retention and recurring engagement beyond single eventsWaitlist + notificationsReduces drop-off when events are full, increases fill rateLeave event feedbackCaptures qualitative data on churn reasons from day one

⚙️ Tech Stack

Frontend: Flutter (Dart)
Backend: Firebase (Firestore, Authentication, Storage, Cloud Messaging)
Maps: Google Maps SDK + Places API
Auth: Firebase Authentication (Email/Password)
Notifications: Firebase Cloud Messaging (FCM)


✅ Features Shipped

🔐 Auth (Sign up / Sign in / Sign out)
🗓️ Event creation with photo, location autocomplete, date/time, capacity
📍 Map view with sport-specific emoji markers
🔔 Waitlist system with push notifications when a spot opens
💬 Real-time community chat per sport
🤝 Discover screen — swipe right to match, left to pass
💌 Direct messaging between matched users
👤 Profile with sport preferences, bio, and photo
📊 Leave event feedback flow (captures churn reasons)
🌍 GDPR-compliant consent screen


📸 Screenshots
Coming soon

🚀 What's Next

iOS TestFlight release
Google Play Store launch
Karma / reputation system for reliable players
Venue partnerships in Karlsruhe
Growth via organic referral within existing sports communities


👤 About
Built by Can Elmas — Product Manager with a passion for zero-to-one products.
This project was built during a 5-month career break focused on German language learning and product exploration in the European market.
LinkedIn · GitHub