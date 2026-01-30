# Community Cloud — Kusala Studio
# AGPLv3 - https://www.gnu.org/licenses/agpl-3.0.html

.PHONY: bootstrap help

help:
	@echo "Targets:"
	@echo "  bootstrap  Create GCP service account, key, and set GCP_SA_KEY in GitHub repo secrets (requires GCP_PROJECT_ID, gcloud, gh)"
	@echo "  help       Show this help (default)"

bootstrap:
	./utils/provision-github-sa.sh
