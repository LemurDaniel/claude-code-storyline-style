// NOTE:
//   Implementation of MiniServer.h. The socket transport is out of scope here,
//   it parses each request and calls MiniServer::handle once per request.

//
//   Chapters:
//     HELPERS      Status codes and the prefix check.
//     LIFECYCLE    begin and stop.
//     ROUTING      Route registration and request handling.
//     MIDDLEWARE   Middleware registration.
//

#include <algorithm>
#include <cstdio>
#include <string>

#include "MiniServer.h"

namespace Http
{
    // ===========================================================================
    // ===============================   HELPERS   ===============================
    // ===========================================================================
    //
    //   HTTP_*       Status codes the server answers with itself.
    //   isPrefixOf   Checks whether a path lies below a middleware prefix.
    //

    namespace
    {
        constexpr int HTTP_NOT_FOUND = 404;
        constexpr int HTTP_SERVICE_UNAVAILABLE = 503;

        bool isPrefixOf(const std::string &prefix, const std::string &path)
        {
            return path.compare(0, prefix.size(), prefix) == 0;
        }
    }

    // ===========================================================================
    // ==============================   LIFECYCLE   ==============================
    // ===========================================================================
    //
    //   begin   Marks the server as running on a port.
    //   stop    Marks the server as stopped.
    //

    int MiniServer::begin(uint16_t port)
    {
        if (_isRunning)
        {
            std::printf("[MiniServer] Already running on port %u -> ignoring begin().\n", _port);
            return 1;
        }

        _port = port;
        _isRunning = true;
        std::printf("[MiniServer] Listening on port %u.\n", _port);
        return 0;
    }

    void MiniServer::stop()
    {
        if (!_isRunning)
        {
            return;
        }

        _isRunning = false;
        std::printf("[MiniServer] Stopped on port %u.\n", _port);
    }

    // ===========================================================================
    // ===============================   ROUTING   ===============================
    // ===========================================================================
    //
    //   get / post   Register a handler for one method, both delegate to addRoute.
    //   addRoute     The one real implementation behind all route registrations.
    //   handle       Runs the matching middlewares, then the first matching route.
    //

    void MiniServer::get(const std::string &path, const RequestHandler &handler)  { addRoute("GET", path, handler); }
    void MiniServer::post(const std::string &path, const RequestHandler &handler) { addRoute("POST", path, handler); }

    void MiniServer::addRoute(const std::string &method, const std::string &path, const RequestHandler &handler)
    {
        _routes.push_back({method, path, handler});
        std::printf("[MiniServer] Registered route %s %s.\n", method.c_str(), path.c_str());
    }

    void MiniServer::handle(Request &request, Response &response)
    {
        if (!_isRunning)
        {
            response.status(HTTP_SERVICE_UNAVAILABLE);
            return;
        }

        // Middlewares run first, in registration order. One of them may answer early (e.g. auth).
        for (const Middleware &middleware : _middlewares)
        {
            if (!isPrefixOf(middleware.prefix, request.path()))
            {
                continue;
            }

            middleware.handler(request, response);
            if (response.isSent())
            {
                std::printf("[MiniServer] Middleware '%s' answered %s -> skipping routes.\n", middleware.prefix.c_str(), request.path().c_str());
                return;
            }
        }

        // The first route with matching method and path wins.
        auto route = std::find_if(_routes.begin(), _routes.end(), [&request](const Route &candidate)
        {
            return candidate.method == request.method() && candidate.path == request.path();
        });

        if (route == _routes.end())
        {
            std::printf("[MiniServer] No route for %s %s -> %d.\n", request.method().c_str(), request.path().c_str(), HTTP_NOT_FOUND);
            response.status(HTTP_NOT_FOUND);
            return;
        }

        route->handler(request, response);
    }

    // ===========================================================================
    // =============================   MIDDLEWARE   ==============================
    // ===========================================================================
    //
    //   use   Registers a middleware for all paths or below a prefix.
    //

    void MiniServer::use(const RequestHandler &handler) { use("/", handler); }

    void MiniServer::use(const std::string &prefix, const RequestHandler &handler)
    {
        _middlewares.push_back({prefix, handler});
        std::printf("[MiniServer] Registered middleware for '%s'.\n", prefix.c_str());
    }
}
