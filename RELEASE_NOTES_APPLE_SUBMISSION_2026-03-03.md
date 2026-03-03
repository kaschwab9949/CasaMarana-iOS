# Casa Marana Apple Submission Freeze - March 3, 2026

## Release SHAs
- iOS app repo (`Square Tier`): `773ae89ec26f22b650ebd2b47e44d90f8862663a`
- Backend repo (`casa-marana-backend`): `dc7a9cfead86376b87d5efe1a5c3bf5565102c79`

## Deployment Sync Verification
- Production URL: `https://casa-marana-backend.vercel.app`
- Health check route: `/api/health`
- Reported deployed commit: `dc7a9cfead86376b87d5efe1a5c3bf5565102c79`
- Sync status: `MATCHED`

## Submission Gate Results
- Release build: PASS
- Unit + UI test suite: PASS
- Signed archive (`xcodebuild archive`): PASS
- Compiled Info.plist backend URL (Debug/Release/Archive): `https://casa-marana-backend.vercel.app`
- Backend protected routes with auth (`/api/menu`, `/api/snake/leaderboard`, `/api/loyalty/status`, `/api/auth/phone/start`, `/api/auth/phone/verify`): PASS

## Final Notes
- Loyalty status client now uses canonical single `phone` query request.
- Customer-facing technical events notice strings were removed from active notice path.
- `CM_BACKEND_BASE_URL` escaping in local xcconfig files was corrected so compiled app no longer embeds `https:`.
