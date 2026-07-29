#!/bin/bash
clear
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'
RESET='\e[0m'
BOLD='\e[1m'

echo -e "${CYAN}${BOLD}"
cat << "EOF"
  ____       _     _ _            __    ___            
 / __ \     | |   (_) |          / _|  / _ \           
| |  | |_ __| |__  _| |_   ___  | |_  | | | |_ __  ___ 
| |  | | '__| '_ \| | __| / _ \ |  _| | | | | '_ \/ __|
| |__| | |  | |_) | | |_ | (_) || |   | |_| | |_) \__ \
 \____/|_|  |_.__/|_|\__| \___/ |_|    \___/| .__/|___/
                                            | |        
                                            |_|        
EOF
echo -e "${RESET}"
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 TARGET: Kickstarting App Dev with Gemini Code Assist  ║${RESET}"
echo -e "${BLUE}${BOLD}║   🌐 BROUGHT TO YOU BY ORBIT OF OPS                        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

export PROJECT_ID=$(gcloud config get-value project)
export REGION=us-central1
export ZONE=us-central1-a

# 1. Setup Environment
echo -e "${YELLOW}${BOLD}Enabling APIs & Downloading Repository...${RESET}"
gcloud services enable apigateway.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com run.googleapis.com firestore.googleapis.com
cd ~
gsutil -m cp -r gs://spls/gsp527/cymbal-superstore .
mkdir -p ~/cymbal-superstore/gateway

# 2. Write Test File
echo -e "${YELLOW}${BOLD}Configuring Backend Tests...${RESET}"
cat << 'EOF' > ~/cymbal-superstore/backend/index.test.ts
// /home/student_01_a2bff002c301/cymbal-superstore/backend/index.test.ts
import request from "supertest";
// Import describe, expect, it from @jest/globals
import {describe, expect, it} from '@jest/globals';

// --- Firestore Mock ---
// This mock needs to be comprehensive enough for the operations in index.ts's global scope
// (e.g., new Firestore(), collection().get(), collection().where().get(), collection().add(), collection().doc().update())
const mockFirestoreDocument = {
  update: jest.fn().mockResolvedValue(undefined),
  // Add other document methods if needed
};

const mockQuerySnapshot = {
  empty: false, // Affects dbRunning and logic in addOrUpdateFirestore
  docs: [{ id: 'mockDocId1', data: () => ({ name: 'Mock Product 1' }) }],
  forEach: jest.fn(callback => {
    mockQuerySnapshot.docs.forEach(doc => callback(doc));
  }),
  // Add other query snapshot properties if needed (e.g., exists for single doc gets)
};

const mockCollection = {
  doc: jest.fn((docId) => {
    // console.log(`Mock Firestore: Accessing doc ${docId}`); // For debugging
    return mockFirestoreDocument;
  }),
  get: jest.fn().mockResolvedValue(mockQuerySnapshot),
  add: jest.fn().mockResolvedValue({ id: 'newMockId' }),
  where: jest.fn().mockReturnThis(), // Allows chaining .where().get()
};

jest.mock('@google-cloud/firestore', () => ({
  Firestore: jest.fn().mockImplementation(() => ({
    collection: jest.fn((collectionName) => {
      // console.log(`Mock Firestore: Accessing collection ${collectionName}`); // For debugging
      return mockCollection;
    }),
  })),
}));
// --- End Firestore Mock ---

// Import app *after* the mocks have been defined and jest.mock has been called
import app from "./index";

describe('GET /health', () => {
	it('should return a 200 status code', async () => {
		const response = await request(app)
			.get('/health');
		expect(response.statusCode).toBe(200);
    expect(response.text).toBe('✅ ok');
	});
});

describe('GET /', () => {
	it('should return a 200 status code', async () => {
		const response = await request(app)
			.get('/');
		expect(response.statusCode).toBe(200);
    expect(response.text).toBe('🍎 Hello! This is the Cymbal Superstore Inventory API.');
	});
});

// implement test for /outofstock here

// Add afterAll hook to potentially close any remaining handles if necessary,
// though with proper mocking, this might not be strictly needed for Firestore.
// For Express apps tested with supertest, explicit server closing is usually not needed
// as supertest handles the server lifecycle for requests.
afterAll(done => {
  // If you had other resources that need explicit closing, do it here.
  // For example, if 'app' was a server instance from app.listen(), you'd do server.close(done).
  // Since 'app' is the Express app itself and supertest manages requests,
  // this is more of a placeholder for general cleanup if other async ops were started by tests.
  done();
});

// Gemini: Write a test for the /outofstock endpoint to verify it returns a status 200 and a list of 2 items.
describe('GET /outofstock', () => {
  it('should return a 200 status code and a list of out of stock products', async () => {
    // Mock Firestore to return specific out-of-stock products
    mockQuerySnapshot.empty = false;
    mockQuerySnapshot.docs = [
      {
        id: 'oos1',
        data: () => ({
          name: 'Wasabi Party Mix',
          price: 5,
          quantity: 0,
          imgfile: 'product-images/wasabipartymix.png',
          timestamp: new Date(),
          actualdateadded: new Date(),
        }),
      },
      {
        id: 'oos2',
        data: () => ({
          name: 'Jalapeno Seasoning',
          price: 3,
          quantity: 0,
          imgfile: 'product-images/jalapenoseasoning.png',
          timestamp: new Date(),
          actualdateadded: new Date(),
        }),
      },
    ];

    const response = await request(app).get('/outofstock');

    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveLength(2);
    expect(response.body[0].name).toBe('Wasabi Party Mix');
    expect(response.body[1].name).toBe('Jalapeno Seasoning');
    expect(response.body[0].quantity).toBe(0);
    expect(response.body[1].quantity).toBe(0);
  });
});
// Subscribe to Tech & Code https://www.youtube.com/@orbitofops
EOF

# 3. Write Backend File
echo -e "${YELLOW}${BOLD}Writing Backend Application Logic...${RESET}"
cat << 'EOF' > ~/cymbal-superstore/backend/index.ts
// # Copyright 2023 Google LLC
// #
// # Licensed under the Apache License, Version 2.0 (the "License");
// # you may not use this file except in compliance with the License.
// # You may obtain a copy of the License at
// #
// #      http://www.apache.org/licenses/LICENSE-2.0
// #
// # Unless required by applicable law or agreed to in writing, software
// # distributed under the License is distributed on an "AS IS" BASIS,
// # ... (omitted standard Apache header lines) ...
// # limitations under the License.
// Init Express.js
import express, { Express, Request, Response } from "express";
let app = express();
let cors = require('cors');
app.use(cors(
  {
    origin: '*'
  }
));
export default app;

// Init env variables (from .env or at runtime from Cloud Run)
import dotenv from "dotenv";
dotenv.config();
const port = process.env.PORT;

var firestore;

// Product object definition
interface Product {
  id?: string; // optional because when we write a new obj to Firestore, we let Firestore set the id.
  name: string;
  price: number; // in USD
  quantity: number; // how many of this product are in stock?
  imgfile: string; // The path to the product image in the uploaded frontend (Cloud Storage)
  timestamp: Date; // A manual or randomly generated timestamp (force X images to have been added in the last week)
  actualdateadded: Date; // The actual datetime the product was added to Firestore (for debugging)
}

// ---------------- HANDLERS ------------------------------------------------
app.get("/", (req: Request, res: Response) => {
  res.send("🍎 Hello! This is the Cymbal Superstore Inventory API.");
});

app.get("/health", (req: Request, res: Response) => {
  res.send("✅ ok");
});

// Get all products from the database
app.get("/products", async (req: Request, res: Response) => {
  const products = await firestore.collection("inventory").get();
  const productsArray: any[] = [];
  products.forEach((product) => {
    const p: Product = {
      id: product.id,
      name: product.data().name,
      price: product.data().price,
      quantity: product.data().quantity,
      imgfile: product.data().imgfile,
      timestamp: product.data().timestamp,
      actualdateadded: product.data().actualdateadded,
    };
    productsArray.push(p);
  });
  res.send(productsArray);
});

// Get product by ID
app.get("/products/:id", async (req: Request, res: Response) => {
  const q_id = req.params.id;
  const product = await firestore.collection("inventory").doc(q_id).get();
  // is product empty?
  if (!product.exists) {
    res.status(404).send("Product not found.");
    return;
  }

  const p: Product = {
    id: product.id,
    name: product.data().name,
    price: product.data().price,
    quantity: product.data().quantity,
    imgfile: product.data().imgfile,
    timestamp: product.data().timestamp,
    actualdateadded: product.data().actualdateadded,
  };
  res.send(p);
});

// This endpoint should return all out-of-stock products.
app.get("/outofstock", async (req: Request, res: Response) => {
  const products = await firestore.collection("inventory").where("quantity", "==", 0).get();
  const productsArray: any[] = [];
  products.forEach((product) => {
    const p: Product = {
      id: product.id,
      name: product.data().name,
      price: product.data().price,
      quantity: product.data().quantity,
      imgfile: product.data().imgfile,
      timestamp: product.data().timestamp,
      actualdateadded: product.data().actualdateadded,
    };
    productsArray.push(p);
  });
  res.send(productsArray);
});

// ------------------- ------------------- ------------------- ------------------- -------------------
// START EXPRESS SERVER
// ------------------- ------------------- ------------------- ------------------- -------------------
  // Init Firestore client with product inventory
  const { Firestore } = require("@google-cloud/firestore");
  firestore = new Firestore();
  initFirestoreCollection();

  var server; 
if (process.env.NODE_ENV !== "test") {
 server = app.listen(port, () => {
    console.log(`🍏 Cymbal Superstore: Inventory API running on port: ${port}`);
  });
}

// ------------------- ------------------- ------------------- ------------------- -------------------
// HELPERS -- SEED THE INVENTORY DATABASE (PRODUCTS)
// ------------------- ------------------- ------------------- ------------------- -------------------

// This will overwrite products in the database - this is intentional, to keep the date-added fresh. (always have a list of products added < 1 week ago, so that
// the new products page always has items to show.
function initFirestoreCollection() {
  const oldProducts = [
    "Apples", "Bananas", "Milk", "Whole Wheat Bread", "Eggs", "Cheddar Cheese",
    "Whole Chicken", "Rice", "Black Beans", "Bottled Water", "Apple Juice",
    "Cola", "Coffee Beans", "Green Tea", "Watermelon", "Broccoli",
    "Jasmine Rice", "Yogurt", "Beef", "Shrimp", "Walnuts", "Sunflower Seeds",
    "Fresh Basil", "Cinnamon",
  ];
  // iterate over product names
  // add "old" products to firestore - all added between 1 month and 12 months ago
  // (none of these should show up in the new products list.)
  for (let i = 0; i < oldProducts.length; i++) {
    const oldProduct = {
      name: oldProducts[i],
      price: Math.floor(Math.random() * 10) + 1,
      quantity: Math.floor(Math.random() * 500) + 1,
      imgfile:
        "product-images/" +
        oldProducts[i].replace(/\s/g, "").toLowerCase() +
        ".png",
      // generate a random timestamp at least 3 months ago (but not more than 12 months ago)
      timestamp: new Date(
        Date.now() - Math.floor(Math.random() * 31536000000) - 7776000000
      ),

      actualdateadded: new Date(Date.now()),
    };
    console.log(
      "⬆️ Adding (or updating) product in firestore: " + oldProduct.name
    );
    addOrUpdateFirestore(oldProduct);
  }
  // Add recent products (force add last 7 days)
  const recentProducts = [
    "Parmesan Crisps", "Pineapple Kombucha", "Maple Almond Butter", "Mint Chocolate Cookies",
    "White Chocolate Caramel Corn", "Acai Smoothie Packs", "Smores Cereal", "Peanut Butter and Jelly Cups",
  ];
  for (let j = 0; j < recentProducts.length; j++) {
    const recent = {
      name: recentProducts[j],
      price: Math.floor(Math.random() * 10) + 1,
      quantity: Math.floor(Math.random() * 100) + 1,
      imgfile:
        "product-images/" +
        recentProducts[j].replace(/\s/g, "").toLowerCase() +
        ".png",
      timestamp: new Date(
        Date.now() - Math.floor(Math.random() * 518400000) + 1
      ),
      actualdateadded: new Date(Date.now()),
    };
    console.log("🆕 Adding (or updating) product in firestore: " + recent.name);
    addOrUpdateFirestore(recent);
  }

  // add recent products that are out of stock (To test demo query- only want to show in stock items.)
  const recentProductsOutOfStock = ["Wasabi Party Mix", "Jalapeno Seasoning"];
  for (let k = 0; k < recentProductsOutOfStock.length; k++) {
    const oosProduct = {
      name: recentProductsOutOfStock[k],
      price: Math.floor(Math.random() * 10) + 1,
      quantity: 0,
      imgfile:
        "product-images/" +
        recentProductsOutOfStock[k].replace(/\s/g, "").toLowerCase() +
        ".png",
      timestamp: new Date(
        Date.now() - Math.floor(Math.random() * 518400000) + 1
      ),
      actualdateadded: new Date(Date.now()),
    };
    console.log(
      "😱 Adding (or updating) out of stock product in firestore: " +
        oosProduct.name
    );
    addOrUpdateFirestore(oosProduct);
  }
}

// Helper - add Firestore doc if not exists, otherwise update
// pass in a Product as the parameter
function addOrUpdateFirestore(product) {
  firestore
    .collection("inventory")
    .where("name", "==", product.name)
    .get()
    .then((querySnapshot) => {
      if (querySnapshot.empty) {
        firestore.collection("inventory").add(product);
      } else {
        querySnapshot.forEach((doc) => {
          firestore.collection("inventory").doc(doc.id).update(product);
        });
      }
    });
}
// Subscribe to Tech & Code https://www.youtube.com/@orbitofops
EOF

# 4. Run tests
echo -e "${YELLOW}${BOLD}Installing dependencies and running tests...${RESET}"
cd ~/cymbal-superstore/backend
npm install --silent
npm run test

# 5. Write Function code
echo -e "${YELLOW}${BOLD}Writing Serverless Cloud Function...${RESET}"
cat << 'EOF' > ~/cymbal-superstore/functions/index.js
const functions = require('@google-cloud/functions-framework');
const {Firestore} = require('@google-cloud/firestore');

// Create a Firestore client
const firestore = new Firestore();

// Create a Cloud Function that will be triggered by an HTTP request
functions.http('newproducts', async (req, res) => {
  // Get the products from Firestore
  const products = await firestore.collection('inventory').where('timestamp', '>', new Date(Date.now() - 604800000)).get();

  initFirestoreCollection();

  // Create an array of products
  const productsArray = [];
  products.forEach((product) => {
    const p = {
      id: product.id,
      name: product.data().name + ' (' + product.data().quantity + ')',
      price: product.data().price,
      quantity: product.data().quantity,
      imgfile: product.data().imgfile,
      timestamp: product.data().timestamp,
      actualdateadded: product.data().actualdateadded,
    };
    productsArray.push(p);
  });

  // Send the products array to the client
  res.set('Access-Control-Allow-Origin', '*');
  res.send(productsArray);
});

// Create a Cloud Function for out-of-stock products
functions.http('outofstock', async (req, res) => {
  // Query Firestore for products with quantity 0 (out of stock)
  const snapshot = await firestore.collection('inventory').where('quantity', '==', 0).get();
  const outOfStock = [];
  snapshot.forEach(doc => {
    outOfStock.push({
      id: doc.id,
      name: doc.data().name,
      price: doc.data().price,
      quantity: doc.data().quantity,
      imgfile: doc.data().imgfile,
      timestamp: doc.data().timestamp,
      actualdateadded: doc.data().actualdateadded
    });
  });
  res.set('Access-Control-Allow-Origin', '*');
  res.status(200).json(outOfStock);
});

// ------------------- ------------------- ------------------- ------------------- -------------------
// HELPERS -- SEED THE INVENTORY DATABASE (PRODUCTS)
// ------------------- ------------------- ------------------- ------------------- -------------------

// This will overwrite products in the database - this is intentional, to keep the date-added fresh.
function initFirestoreCollection() {
  const oldProducts = [
    "Apples", "Bananas", "Milk", "Whole Wheat Bread", "Eggs", "Cheddar Cheese",
    "Whole Chicken", "Rice", "Black Beans", "Bottled Water", "Apple Juice",
    "Cola", "Coffee Beans", "Green Tea", "Watermelon", "Broccoli",
    "Jasmine Rice", "Yogurt", "Beef", "Shrimp", "Walnuts", "Sunflower Seeds",
    "Fresh Basil", "Cinnamon",
  ];
  // Add "old" products to Firestore
  for (let i = 0; i < oldProducts.length; i++) {
    const oldProduct = {
      name: oldProducts[i],
      price: Math.floor(Math.random() * 10) + 1,
      quantity: Math.floor(Math.random() * 500) + 1,
      imgfile: "product-images/" + oldProducts[i].replace(/\s/g, "").toLowerCase() + ".png",
      timestamp: new Date(Date.now() - Math.floor(Math.random() * 31536000000) - 7776000000),
      actualdateadded: new Date(Date.now()),
    };
    console.log("Adding (or updating) product in firestore: " + oldProduct.name);
    addOrUpdateFirestore(oldProduct);
  }
  // Add recent products
  const recentProducts = [
    "Parmesan Crisps", "Pineapple Kombucha", "Maple Almond Butter", "Mint Chocolate Cookies",
    "White Chocolate Caramel Corn", "Acai Smoothie Packs", "Smores Cereal", "Peanut Butter and Jelly Cups",
  ];
  for (let j = 0; j < recentProducts.length; j++) {
    const recent = {
      name: recentProducts[j],
      price: Math.floor(Math.random() * 10) + 1,
      quantity: Math.floor(Math.random() * 100) + 1,
      imgfile: "product-images/" + recentProducts[j].replace(/\s/g, "").toLowerCase() + ".png",
      timestamp: new Date(Date.now() - Math.floor(Math.random() * 518400000) + 1),
      actualdateadded: new Date(Date.now()),
    };
    console.log("Adding (or updating) product in firestore: " + recent.name);
    addOrUpdateFirestore(recent);
  }
  // Add recent products that are out of stock
  const recentProductsOutOfStock = ["Wasabi Party Mix", "Jalapeno Seasoning"];
  for (let k = 0; k < recentProductsOutOfStock.length; k++) {
    const oosProduct = {
      name: recentProductsOutOfStock[k],
      price: Math.floor(Math.random() * 10) + 1,
      quantity: 0,
      imgfile: "product-images/" + recentProductsOutOfStock[k].replace(/\s/g, "").toLowerCase() + ".png",
      timestamp: new Date(Date.now() - Math.floor(Math.random() * 518400000) + 1),
      actualdateadded: new Date(Date.now()),
    };
    console.log("Adding (or updating) out of stock product in firestore: " + oosProduct.name);
    addOrUpdateFirestore(oosProduct);
  }
}

// Helper - add Firestore doc if not exists, otherwise update
function addOrUpdateFirestore(product) {
  firestore
    .collection("inventory")
    .where("name", "==", product.name)
    .get()
    .then((querySnapshot) => {
      if (querySnapshot.empty) {
        firestore.collection("inventory").add(product);
      } else {
        querySnapshot.forEach((doc) => {
          firestore.collection("inventory").doc(doc.id).update(product);
        });
      }
    });
}
// Subscribe to Tech & Code https://www.youtube.com/@orbitofops
EOF

# 6. Deploy function
echo -e "${YELLOW}${BOLD}Deploying Cloud Function (approx. 2 mins)...${RESET}"
cd ~/cymbal-superstore/functions
gcloud functions deploy outofstock --runtime=nodejs20 --trigger-http --entry-point=outofstock --region=$REGION --allow-unauthenticated --quiet

# 7. Write Gateway Config dynamically
echo -e "${YELLOW}${BOLD}Configuring API Gateway...${RESET}"
export FUNCTION_URL=$(gcloud functions describe outofstock --region=$REGION --format="value(httpsTrigger.url)")
export FUNCTION_HOST=$(echo $FUNCTION_URL | sed -e 's|^https://||' -e 's|/.*||')

cat << EOF > ~/cymbal-superstore/gateway/outofstock.yaml
swagger: '2.0'
info:
  title: OutOfStock API
  version: 1.0.0
host: ${FUNCTION_HOST}
schemes:
  - https
paths:
  /outofstock:
    get:
      summary: Get out of stock products
      operationId: outofstock
      x-google-backend:
        address: ${FUNCTION_URL}
      responses:
        '200':
          description: Successful response
          schema:
            type: array
            items:
              type: object
security: []
# Brought to you by Orbit of Ops
EOF

# 8. Deploy Gateway
echo -e "${YELLOW}${BOLD}Deploying API Gateway (approx. 3-5 mins)...${RESET}"
cd ~/cymbal-superstore/gateway
export CONFIG_ID=outofstock-api-config
export API_ID=outofstock-api
export GATEWAY_ID=store

gcloud api-gateway apis create $API_ID --display-name="Out of Stock API" --quiet || true
gcloud api-gateway api-configs create $CONFIG_ID --api=$API_ID --openapi-spec=outofstock.yaml --display-name="Out of Stock API Config" --quiet
gcloud api-gateway gateways create $GATEWAY_ID --api=$API_ID --api-config=$CONFIG_ID --location=$REGION --quiet

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║           🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
