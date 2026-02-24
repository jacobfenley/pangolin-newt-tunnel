#!/bin/bash
set -e

# ============================================================
# Pangolin Newt Setup Wizard
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/newt.env"
SECRET_FILE="$SCRIPT_DIR/newt-config.secret"

print_header() {
    echo ""
    echo "========================================"
    echo "     Pangolin Newt Setup Wizard"
    echo "========================================"
    echo ""
}

# Check if an existing config is present and ask before overwriting
check_existing() {
    if [ -f "$ENV_FILE" ]; then
        existing_endpoint=""
        existing_id=""
        if grep -q "PANGOLIN_ENDPOINT=" "$ENV_FILE" 2>/dev/null; then
            existing_endpoint=$(grep "^PANGOLIN_ENDPOINT=" "$ENV_FILE" | cut -d= -f2-)
        fi
        if grep -q "NEWT_ID=" "$ENV_FILE" 2>/dev/null; then
            existing_id=$(grep "^NEWT_ID=" "$ENV_FILE" | cut -d= -f2-)
        fi

        echo "An existing configuration was found:"
        echo "  Endpoint : ${existing_endpoint:-<not set>}"
        echo "  ID       : ${existing_id:-<not set>}"
        echo "  Secret   : <hidden>"
        echo ""
        printf "Overwrite existing configuration? [y/N]: " > /dev/tty
        read -r confirm < /dev/tty
        case "$confirm" in
            [yY]|[yY][eE][sS]) ;;
            *)
                echo "Aborted. Existing configuration unchanged."
                exit 0
                ;;
        esac
        echo ""
    fi
}

# Prompt for endpoint with default
prompt_endpoint() {
    local default="https://app.pangolin.net"
    printf "Endpoint URL [%s]: " "$default" > /dev/tty
    read -r input_endpoint < /dev/tty
    if [ -z "$input_endpoint" ]; then
        PANGOLIN_ENDPOINT="$default"
    else
        PANGOLIN_ENDPOINT="$input_endpoint"
    fi
}

# Prompt for Site ID — required
prompt_id() {
    while true; do
        printf "Site ID: " > /dev/tty
        read -r NEWT_ID < /dev/tty
        if [ -n "$NEWT_ID" ]; then
            break
        fi
        echo "Site ID is required. Please enter your Site ID." > /dev/tty
    done
}

# Prompt for Site Secret — required, hidden input
prompt_secret() {
    while true; do
        printf "Site Secret: " > /dev/tty
        read -rs NEWT_SECRET < /dev/tty
        echo "" > /dev/tty
        if [ -n "$NEWT_SECRET" ]; then
            break
        fi
        echo "Site Secret is required. Please enter your Site Secret." > /dev/tty
    done
}

# Prompt for Node label — optional, defaults to hostname
prompt_label() {
    local default_label
    default_label="$(hostname)"
    printf "Node label [%s]: " "$default_label" > /dev/tty
    read -r input_label < /dev/tty
    if [ -z "$input_label" ]; then
        NEWT_LABEL="$default_label"
    else
        NEWT_LABEL="$input_label"
    fi
}

# Confirm before writing
confirm_and_write() {
    echo ""
    echo "----------------------------------------"
    echo "Review your configuration:"
    echo "  Endpoint   : $PANGOLIN_ENDPOINT"
    echo "  ID         : $NEWT_ID"
    echo "  Node label : $NEWT_LABEL"
    echo "  Secret     : <hidden>"
    echo "----------------------------------------"
    echo ""
    printf "Write configuration files? [Y/n]: " > /dev/tty
    read -r confirm < /dev/tty
    case "$confirm" in
        [nN]|[nN][oO])
            echo "Aborted. No files written."
            exit 0
            ;;
    esac

    # Write newt.env
    cat > "$ENV_FILE" <<EOF
PANGOLIN_ENDPOINT=${PANGOLIN_ENDPOINT}
NEWT_ID=${NEWT_ID}
NEWT_SECRET=${NEWT_SECRET}
NEWT_LABEL=${NEWT_LABEL}
EOF
    chmod 600 "$ENV_FILE"

    # Write newt-config.secret (JSON)
    cat > "$SECRET_FILE" <<EOF
{
  "id": "${NEWT_ID}",
  "secret": "${NEWT_SECRET}",
  "endpoint": "${PANGOLIN_ENDPOINT}",
  "tlsClientCert": ""
}
EOF
    chmod 600 "$SECRET_FILE"

    echo ""
    echo "Configuration written:"
    echo "  $ENV_FILE (mode 600)"
    echo "  $SECRET_FILE (mode 600)"
}

print_next_steps() {
    echo ""
    echo "========================================"
    echo "Setup complete."
    echo ""
    echo "Next steps:"
    echo "  1. Start your tunnel:"
    echo "       docker compose up -d"
    echo ""
    echo "  2. Confirm Newt is connected:"
    echo "       docker compose logs newt"
    echo ""
    echo "  3. Run the smoke test to verify end-to-end routing:"
    echo "       docker compose --profile test up -d"
    echo "     Then create a Pangolin resource pointing to localhost:17480"
    echo "     See README.md -> Testing Your Tunnel for full instructions."
    echo ""
    echo "  4. Stop the test server when done:"
    echo "       docker compose --profile test down"
    echo "========================================"
    echo ""
}

# ---- Main ----
print_header
check_existing
prompt_endpoint
prompt_id
prompt_secret
prompt_label
confirm_and_write
print_next_steps
