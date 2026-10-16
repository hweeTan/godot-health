#pragma once

#include <functional>
#include <string>

bool healthkit_is_available();

void healthkit_request_authorization(const std::function<void(bool ok, const std::string &error)> &done);

void healthkit_read_recent(const std::function<void(const std::string &json)> &done);
