# Use the official Elixir image
FROM elixir:1.18.4-otp-28

# Set environment variables
ENV MIX_ENV=dev

# Create app directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies
RUN mix deps.get

# Copy config files
COPY config ./config

# Copy assets
COPY assets ./assets

# Copy lib
COPY lib ./lib

# Copy priv
COPY priv ./priv

# Back to app directory
WORKDIR /app

# Compile the application
RUN mix deps.compile
RUN mix compile

# Start the Phoenix server
CMD ["mix", "phx.server"]
