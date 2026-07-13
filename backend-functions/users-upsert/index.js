function getRequiredEnv(name) {
  const value = process.env[name];
  if (!value || !String(value).trim()) {
    throw new Error(`Missing required app setting: ${name}`);
  }
  return String(value).trim();
}

function buildMasterKeyAuth({ verb, resourceType, resourceLink, date, key }) {
  const crypto = require("crypto");
  const payload = `${verb.toLowerCase()}\n${resourceType.toLowerCase()}\n${resourceLink}\n${date.toLowerCase()}\n\n`;
  const body = Buffer.from(payload, "utf8");
  const signingKey = Buffer.from(key, "base64");
  const signature = crypto.createHmac("sha256", signingKey).update(body).digest("base64");
  return encodeURIComponent(`type=master&ver=1.0&sig=${signature}`);
}

async function upsertUserToCosmos(userDoc) {
  const endpoint = getRequiredEnv("COSMOS_DB_ENDPOINT").replace(/\/+$/, "");
  const key = getRequiredEnv("COSMOS_DB_KEY");
  const databaseId = getRequiredEnv("COSMOS_DB_DATABASE");
  const containerId = getRequiredEnv("COSMOS_DB_CONTAINER");
  const resourceLink = `dbs/${databaseId}/colls/${containerId}`;
  const resourceType = "docs";
  const utcDate = new Date().toUTCString();
  const auth = buildMasterKeyAuth({
    verb: "POST",
    resourceType,
    resourceLink,
    date: utcDate,
    key
  });
  const url = `${endpoint}/${resourceLink}/docs`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: auth,
      "x-ms-date": utcDate,
      "x-ms-version": "2018-12-31",
      "x-ms-documentdb-is-upsert": "true",
      "x-ms-documentdb-partitionkey": JSON.stringify([userDoc.id]),
      "Content-Type": "application/json"
    },
    body: JSON.stringify(userDoc)
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Cosmos REST failed (${response.status}): ${errorText}`);
  }

  return response.json();
}

module.exports = async function (context, req) {
  const body = req && req.body && typeof req.body === "object" ? req.body : null;

  if (!body) {
    context.res = {
      status: 400,
      headers: { "Content-Type": "application/json" },
      body: { ok: false, message: "요청 본문(JSON)이 필요함" }
    };
    return;
  }

  const id = String(body.id || "").trim();
  const provider = String(body.provider || "").trim();
  if (!id || !provider) {
    context.res = {
      status: 400,
      headers: { "Content-Type": "application/json" },
      body: { ok: false, message: "id와 provider는 필수값임" }
    };
    return;
  }

  const now = new Date().toISOString();
  const userDoc = {
    id,
    provider,
    displayName: String(body.displayName || "").trim(),
    email: String(body.email || "").trim(),
    picture: String(body.picture || "").trim(),
    updatedAt: now
  };

  try {
    const resource = await upsertUserToCosmos(userDoc);
    context.res = {
      status: 200,
      headers: { "Content-Type": "application/json" },
      body: { ok: true, id: resource.id, updatedAt: resource.updatedAt }
    };
  } catch (error) {
    context.log.error("Cosmos upsert failed", error);
    context.res = {
      status: 500,
      headers: { "Content-Type": "application/json" },
      body: { ok: false, message: "Cosmos upsert 실패", detail: error.message }
    };
  }
};
