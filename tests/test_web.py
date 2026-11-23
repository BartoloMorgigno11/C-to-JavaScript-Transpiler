"""Focused Flask endpoint tests that do not invoke the native toolchain."""

from __future__ import annotations

import unittest

from web.app import app


class WebEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = app.test_client()

    def test_empty_transpile_request_is_rejected(self) -> None:
        response = self.client.post("/api/transpile", json={"source": "  "})
        self.assertEqual(response.status_code, 400)
        self.assertFalse(response.get_json()["ok"])

    def test_artifact_route_rejects_path_traversal(self) -> None:
        response = self.client.get("/files/../../README.md")
        self.assertEqual(response.status_code, 404)


if __name__ == "__main__":
    unittest.main()
