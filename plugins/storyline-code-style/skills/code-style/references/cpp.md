# Code Style: C++
- 4 spaces, Allman braces, everything in its own namespace. If the project has a license header, it goes in every file.
  ```cpp
  // SPDX-License-Identifier: MIT
  // Copyright (c) <YEAR> <AUTHOR>

  namespace Http
  {
      void Router::handle(Request &request)
      {
          if (!_isRunning)
          {
              return;
          }
          ...
      }
  }
  ```
- The formatter is clang-format with a `.clang-format` in the repo root:
  ```yaml
  # .clang-format
  BasedOnStyle: LLVM
  IndentWidth: 4
  BreakBeforeBraces: Allman
  AccessModifierOffset: -4
  ColumnLimit: 120
  ```
- Doxygen `/** @brief */` on every member, `@param` columns aligned, examples in backticks:
  ```cpp
  /**
   * @brief Starts the HTTP server on the given port and spawns worker tasks.
   * @param port        TCP port to listen on (e.g. 80).
   * @param workerCount Number of worker tasks (default 3).
   * @return 0 on success, non-zero on failure.
   */
  ```
- Headers grouped by feature. `public:` and `private:` may alternate. A header with one class gets one chapter around the class, its description lists the groups and so serves as the table of contents of the class. The `.cpp` uses the same group names as chapter titles.
  ```cpp
  // ===========================================================================
  // =========================   ROUTE HTTP REQUESTS   =========================
  // ===========================================================================
  //
  //   Lifecycle    begin and stop, the running flag and the port.
  //   Routing      get, post and handle, routes match method and exact path.
  //   Middleware   use, middlewares match a path prefix and may answer early.
  //

  class MiniServer
  {
  // Routing
  public:
      void get(const std::string &path, const RequestHandler &handler);
      void post(const std::string &path, const RequestHandler &handler);
  private:
      void addRoute(const std::string &method, const std::string &path, const RequestHandler &handler);
      std::vector<Route> _routes;

  // Middleware
  public:
      void use(const RequestHandler &handler);
  private:
      std::vector<Middleware> _middlewares;
  };
  ```
- `.cpp` files structure chapters and sections as `//` banners per `SKILL.md` → "Comments". No `/*---- * Title *` blocks.
  ```cpp
  // ===========================================================================
  // =============================   MIDDLEWARE   ==============================
  // ===========================================================================
  //
  //   use      Registers a handler for all paths below a prefix.
  //   handle   Runs the matching handlers in registration order.
  //

  // ---------------------------------------------------------------------------
  // Handle Middleware
  ```
- Includes grouped: framework, stdlib, libraries, own.
  ```cpp
  #include <QCoreApplication>
  #include <QTcpServer>

  #include <functional>
  #include <string>
  #include <vector>

  #include <nlohmann/json.hpp>

  #include "MiniServer.h"
  #include "Router.h"
  ```
- `_member`, methods in camelCase, constants in `UPPER_SNAKE`, flags as `bool` with an `is` prefix.
  ```cpp
  static constexpr uint16_t DEFAULT_PORT = 80;

  bool _isRunning = false;
  uint8_t _workerCount = 3;

  void startWorkers();
  ```
- Lambdas follow Allman as well.
  ```cpp
  std::sort(routes.begin(), routes.end(), [](const Route &left, const Route &right)
  {
      return left.path.size() > right.path.size();
  });
  ```
- Logs with a component prefix, through the project's logger or `printf`.
  ```cpp
  std::printf("[MiniServer] Listening on port %u with %u workers\n", port, workerCount);
  ```
