import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export function GET() {
  const fps = (process.env.ANDROID_SIGNING_SHA256 ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const body = ["com.orbix.app", "com.orbixcloud.app"].map((pkg) => ({
    relation: ["delegate_permission/common.handle_all_urls"],
    target: { namespace: "android_app", package_name: pkg, sha256_cert_fingerprints: fps },
  }));
  return NextResponse.json(body);
}
