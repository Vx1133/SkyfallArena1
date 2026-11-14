# Roblox cloud publishing setup

Publishing is intentionally separate from source validation. A build artifact can be produced without a Roblox API key, but publishing it requires an existing Roblox place.

## What is needed

1. An existing Roblox experience and the Place ID of the place to update.
2. A Roblox Open Cloud API key created in Creator Dashboard.
3. The key configured as a GitHub Actions repository secret named ROBLOX_API_KEY.
4. The numeric Place ID configured as a GitHub Actions repository variable named ROBLOX_PLACE_ID.

Do not paste the API key into chat, commit it to the repository, or put it in a Luau file.

## Required Roblox key permissions

Use the Assets API permissions for the intended experience and grant only the read and write operations needed for place publishing. Do not grant broad access to unrelated experiences.

## Publishing endpoint

The current Roblox Creator Hub guide documents the Assets API update endpoint:

PATCH https://apis.roblox.com/assets/v1/assets/{placeId}

The API key is sent in the x-api-key header. The multipart request includes a request field with the Place asset ID, asset type Place, and published true, plus the generated RBXLX file as fileContent with application/xml content type.

The API returns an operation ID. A publishing workflow must poll the Assets API operation endpoint until done is true and confirm that isPublished is true. It must fail visibly when the operation returns an error.

## Not enabled in this foundation

No publishing workflow is included yet. The repository does not currently have the target Place ID or a configured GitHub secret. The validation workflow only produces an artifact and cannot change a live Roblox experience.

Official guide: https://create.roblox.com/docs/cloud/guides/usage-place-publishing
