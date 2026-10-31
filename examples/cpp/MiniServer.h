// NOTE:
//   Requires: C++17, Request.h and Response.h of the transport layer.
//
//   Http::MiniServer server;
//   server.use("/api", Http::auth(API_TOKEN));
//   server.get("/api/status", handleStatus);
//   server.begin(Http::MiniServer::DEFAULT_PORT);

//
//   Chapters:
//     ROUTE HTTP REQUESTS   The MiniServer class with lifecycle, routing and middleware.
//

#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "Request.h"
#include "Response.h"

namespace Http
{
    // ===========================================================================
    // =========================   ROUTE HTTP REQUESTS   =========================
    // ===========================================================================
    //
    //   Lifecycle    begin and stop, the running flag and the port.
    //   Routing      get, post and handle, routes match method and exact path.
    //   Middleware   use, middlewares match a path prefix and may answer early.
    //
    //   The implementation follows the same sections, see MiniServer.cpp.
    //

    using RequestHandler = std::function<void(Request &, Response &)>;

    /**
     * @brief Small HTTP router that runs the middlewares and the matching route per request.
     */
    class MiniServer
    {
    // ---------------------------------------------------------------------------
    // Lifecycle
    //   begin and stop, the running flag and the port.
    // ---------------------------------------------------------------------------
    public:
        static constexpr uint16_t DEFAULT_PORT = 80;

        /**
         * @brief Starts accepting requests on the given port.
         * @param port TCP port to listen on (default 80).
         * @return 0 on success, non-zero when the server already runs.
         */
        int begin(uint16_t port = DEFAULT_PORT);

        /**
         * @brief Stops accepting requests. Does nothing when the server is not running.
         */
        void stop();

    private:
        bool _isRunning = false;
        uint16_t _port = 0;

    // ---------------------------------------------------------------------------
    // Routing
    //   get, post and handle, routes match method and exact path.
    // ---------------------------------------------------------------------------
    public:
        /**
         * @brief Registers a handler for GET requests on an exact path.
         * @param path    Path to match (e.g. `/api/status`).
         * @param handler Handler that answers the request.
         */
        void get(const std::string &path, const RequestHandler &handler);

        /**
         * @brief Registers a handler for POST requests on an exact path.
         * @param path    Path to match (e.g. `/api/items`).
         * @param handler Handler that answers the request.
         */
        void post(const std::string &path, const RequestHandler &handler);

        /**
         * @brief Runs the matching middlewares, then the first matching route.
         * @param request  The parsed request from the transport layer.
         * @param response The response to fill.
         */
        void handle(Request &request, Response &response);

    private:
        struct Route
        {
            std::string method;
            std::string path;
            RequestHandler handler;
        };

        void addRoute(const std::string &method, const std::string &path, const RequestHandler &handler);
        std::vector<Route> _routes;

    // ---------------------------------------------------------------------------
    // Middleware
    //   use, middlewares match a path prefix and may answer early.
    // ---------------------------------------------------------------------------
    public:
        /**
         * @brief Registers a middleware for all paths.
         * @param handler Middleware that may answer the request early (e.g. auth).
         */
        void use(const RequestHandler &handler);

        /**
         * @brief Registers a middleware for all paths below a prefix.
         * @param prefix  Path prefix to match (e.g. `/api`).
         * @param handler Middleware that may answer the request early (e.g. auth).
         */
        void use(const std::string &prefix, const RequestHandler &handler);

    private:
        struct Middleware
        {
            std::string prefix;
            RequestHandler handler;
        };

        std::vector<Middleware> _middlewares;
    };
}
