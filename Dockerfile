# Use the official Elixir image
FROM elixir:1.16-alpine

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm \
    inotify-tools

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

# Install node dependencies for assets
WORKDIR /app/assets
RUN npm install

# Back to app directory
WORKDIR /app

# Compile the application
RUN mix compile

# Expose port
EXPOSE 4000

# Start the Phoenix server
CMD ["mix", "phx.server"]
