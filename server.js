const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const cors = require('cors');
const app = express();
const uri = "mongodb://localhost:27017";
const client = new MongoClient(uri);

app.use(express.json());
app.use(cors({ origin: '*' })); // Allow all origins for development

// Database Connection with Retry
async function connectDB() {
    let retries = 5;
    while (retries) {
        try {
            await client.connect();
            console.log("Connected to MongoDB");
            return client.db("ParkingSystem");
        } catch (error) {
            console.error("MongoDB connection failed:", error);
            retries -= 1;
            if (retries === 0) {
                console.error("Max retries reached. Exiting...");
                process.exit(1);
            }
            console.log(`Retrying connection (${5 - retries}/5)...`);
            await new Promise(res => setTimeout(res, 2000));
        }
    }
}

const dbPromise = connectDB();

// Register Parking Area Owner
app.post('/api/owner/register', async (req, res) => {
    const { phone, parking_area_name, password } = req.body;
    const db = await dbPromise;

    try {
        console.log(`Registering owner with phone: ${phone}`);
        const existingUser = await db.collection('register_login').findOne({ phone });
        if (existingUser) {
            console.log(`User with phone ${phone} already exists`);
            return res.status(400).json({ message: "User already exists" });
        }

        const user = {
            phone,
            parking_area_name,
            password, // In production, use bcrypt to hash this
            createdAt: new Date(),
        };
        await db.collection('register_login').insertOne(user);
        console.log(`Owner registered successfully`);
        res.status(200).json({ message: "Registered successfully" });
    } catch (error) {
        console.error("Error registering owner:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Login Parking Area Owner
app.post('/api/owner/login', async (req, res) => {
    const { phone, password } = req.body;
    const db = await dbPromise;

    try {
        console.log(`Logging in owner with phone: ${phone}`);
        const user = password
            ? await db.collection('register_login').findOne({ phone, password })
            : await db.collection('register_login').findOne({ phone }); // Allow fetching without password for profile
        if (!user) {
            console.log(`Invalid credentials for phone: ${phone}`);
            return res.status(400).json({ message: "Invalid credentials" });
        }
        console.log(`Login successful for phone: ${phone}`);
        res.status(200).json({
            message: "Login successful",
            phone: user.phone,
            parking_area_name: user.parking_area_name,
        });
    } catch (error) {
        console.error("Error logging in owner:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Update or Create Parking Area
app.post('/api/owner/parking_areas', async (req, res) => {
    const { name, parking_area_name, location, total_car_slots, total_bike_slots } = req.body;
    const db = await dbPromise;

    try {
        console.log("Processing parking area with data:", { name, parking_area_name, location, total_car_slots, total_bike_slots });
        const existingArea = await db.collection('parking_areas').findOne({ name });

        if (existingArea) {
            // Update existing parking area
            const currentCarSlots = existingArea.total_car_slots;
            const currentBikeSlots = existingArea.total_bike_slots;
            const carSlotsDiff = total_car_slots - currentCarSlots;
            const bikeSlotsDiff = total_bike_slots - currentBikeSlots;

            // Update parking area details
            const updateResult = await db.collection('parking_areas').updateOne(
                { name },
                {
                    $set: {
                        location: { lat: location.lat, lng: location.lng },
                        total_car_slots,
                        total_bike_slots,
                        updatedAt: new Date(),
                    },
                    $inc: {
                        available_car_slots: carSlotsDiff > 0 ? carSlotsDiff : 0,
                        available_bike_slots: bikeSlotsDiff > 0 ? bikeSlotsDiff : 0,
                    },
                }
            );

            // Update parking_area_name in register_login
            await db.collection('register_login').updateOne(
                { phone: name },
                { $set: { parking_area_name, updatedAt: new Date() } }
            );

            console.log(`Parking area ${name} updated: ${updateResult.modifiedCount} document(s) modified`);

            // Adjust slots if total slots increased or decreased
            if (carSlotsDiff !== 0 || bikeSlotsDiff !== 0) {
                const parkingId = existingArea._id;

                // Fetch existing slots
                const existingSlots = await db.collection('slots').find({ parking_id: parkingId }).toArray();
                const carSlots = existingSlots.filter(slot => slot.vehicle_type === 'car');
                const bikeSlots = existingSlots.filter(slot => slot.vehicle_type === 'bike');

                // Handle car slots
                if (carSlotsDiff > 0) {
                    const newCarSlots = Array.from({ length: carSlotsDiff }, (_, i) => ({
                        parking_id: parkingId,
                        slot_number: currentCarSlots + i + 1,
                        vehicle_type: "car",
                        status: "available",
                        current_booking_id: null,
                    }));
                    await db.collection('slots').insertMany(newCarSlots);
                    console.log(`Added ${carSlotsDiff} new car slots`);
                } else if (carSlotsDiff < 0) {
                    const slotsToRemove = carSlots
                        .filter(slot => slot.status === "available")
                        .slice(0, -carSlotsDiff);
                    if (slotsToRemove.length > 0) {
                        await db.collection('slots').deleteMany({
                            _id: { $in: slotsToRemove.map(slot => slot._id) },
                        });
                        console.log(`Removed ${slotsToRemove.length} car slots`);
                    }
                }

                // Handle bike slots
                if (bikeSlotsDiff > 0) {
                    const newBikeSlots = Array.from({ length: bikeSlotsDiff }, (_, i) => ({
                        parking_id: parkingId,
                        slot_number: currentBikeSlots + i + 1,
                        vehicle_type: "bike",
                        status: "available",
                        current_booking_id: null,
                    }));
                    await db.collection('slots').insertMany(newBikeSlots);
                    console.log(`Added ${bikeSlotsDiff} new bike slots`);
                } else if (bikeSlotsDiff < 0) {
                    const slotsToRemove = bikeSlots
                        .filter(slot => slot.status === "available")
                        .slice(0, -bikeSlotsDiff);
                    if (slotsToRemove.length > 0) {
                        await db.collection('slots').deleteMany({
                            _id: { $in: slotsToRemove.map(slot => slot._id) },
                        });
                        console.log(`Removed ${slotsToRemove.length} bike slots`);
                    }
                }
            }

            res.status(200).json({ message: "Parking area updated successfully" });
        } else {
            // Create new parking area
            const parkingArea = {
                name, // Use phone as name
                location: { lat: location.lat, lng: location.lng },
                total_car_slots,
                available_car_slots: total_car_slots,
                booked_car_slots: 0,
                total_bike_slots,
                available_bike_slots: total_bike_slots,
                booked_bike_slots: 0,
                createdAt: new Date(),
            };
            const result = await db.collection('parking_areas').insertOne(parkingArea);

            // Update parking_area_name in register_login
            await db.collection('register_login').updateOne(
                { phone: name },
                { $set: { parking_area_name, updatedAt: new Date() } }
            );

            console.log(`Parking area created with ID: ${result.insertedId}`);

            // Create slots
            const carSlots = Array.from({ length: total_car_slots }, (_, i) => ({
                parking_id: result.insertedId,
                slot_number: i + 1,
                vehicle_type: "car",
                status: "available",
                current_booking_id: null,
            }));
            const bikeSlots = Array.from({ length: total_bike_slots }, (_, i) => ({
                parking_id: result.insertedId,
                slot_number: i + 1,
                vehicle_type: "bike",
                status: "available",
                current_booking_id: null,
            }));
            const slotsResult = await db.collection('slots').insertMany([...carSlots, ...bikeSlots]);
            console.log(`Inserted ${slotsResult.insertedCount} slots`);

            res.status(200).json({ message: "Parking area created", id: result.insertedId });
        }
    } catch (error) {
        console.error("Error processing parking area:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Get Parking Areas
app.get('/api/owner/parking_areas', async (req, res) => {
    const db = await dbPromise;

    try {
        console.log("Fetching all parking areas...");
        const parkingAreas = await db.collection('parking_areas').find().toArray();
        console.log("Parking areas fetched:", parkingAreas);
        res.status(200).json(parkingAreas);
    } catch (error) {
        console.error("Error fetching parking areas:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Get Slots for a Parking Area
app.get('/api/owner/parking_areas/:id/slots', async (req, res) => {
    const db = await dbPromise;
    const { vehicle_type } = req.query;
    const parkingId = new ObjectId(req.params.id);

    try {
        console.log(`Fetching slots for parking_id: ${req.params.id}, vehicle_type: ${vehicle_type}`);
        const query = { parking_id: parkingId };
        if (vehicle_type) query.vehicle_type = vehicle_type.toLowerCase();

        const slots = await db.collection('slots').find(query).toArray();
        const activeBookings = await db.collection('bookings')
            .find({ parking_id: parkingId, status: "active" })
            .toArray();
        const bookedSlotIds = activeBookings.map(b => b.slot_id.toString());

        const slotsWithStatus = slots.map(slot => ({
            ...slot,
            is_booked: bookedSlotIds.includes(slot._id.toString()),
        }));

        console.log(`Returning ${slotsWithStatus.length} slots`);
        res.status(200).json(slotsWithStatus);
    } catch (error) {
        console.error("Error fetching slots:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Book a Slot
app.post('/api/owner/bookings', async (req, res) => {
    const { parking_id, slot_id, vehicle_type, number_plate, entry_time, phone } = req.body;
    const db = await dbPromise;

    try {
        console.log("Booking slot with data:", { parking_id, slot_id, vehicle_type, number_plate, entry_time });
        const slot = await db.collection('slots').findOne({ _id: new ObjectId(slot_id) });
        if (!slot || slot.status !== "available") {
            console.log(`Slot ${slot_id} not available`);
            return res.status(400).json({ message: "Slot not available" });
        }

        const booking = {
            parking_id: new ObjectId(parking_id),
            slot_id: new ObjectId(slot_id),
            vehicle_type: vehicle_type.toLowerCase(),
            number_plate,
            phone,
            entry_time: new Date(entry_time),
            status: "active",
            createdAt: new Date(),
        };
        const result = await db.collection('bookings').insertOne(booking);
        console.log(`Booking created with ID: ${result.insertedId}`);

        await db.collection('slots').updateOne(
            { _id: new ObjectId(slot_id) },
            { $set: { status: "booked", current_booking_id: result.insertedId } }
        );

        const updateField = vehicle_type.toLowerCase() === "car"
            ? { $inc: { available_car_slots: -1, booked_car_slots: 1 } }
            : { $inc: { available_bike_slots: -1, booked_bike_slots: 1 } };
        await db.collection('parking_areas').updateOne(
            { _id: new ObjectId(parking_id) },
            updateField
        );

        res.status(200).json({
            message: "Slot booked",
            booking_id: result.insertedId,
            slot_number: slot.slot_number,
        });
    } catch (error) {
        console.error("Error booking slot:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Get Booking Details
app.get('/api/owner/bookings', async (req, res) => {
    const { slot_id } = req.query;
    const db = await dbPromise;

    try {
        console.log(`Fetching booking for slot_id: ${slot_id}`);
        const bookings = await db.collection('bookings').find({
            slot_id: new ObjectId(slot_id),
            status: "active",
        }).toArray();
        console.log("Bookings fetched:", bookings);
        res.status(200).json(bookings);
    } catch (error) {
        console.error("Error fetching bookings:", error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
});

// Start Server on Port 4000
app.listen(4000, () => console.log("Server running on port 4000"));