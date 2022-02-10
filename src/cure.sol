// SPDX-License-Identifier: AGPL-3.0-or-later

/// cure.sol -- Debt Rectifier contract

// Copyright (C) 2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.6.12;

interface SourceLike {
    function cure() external view returns (uint256);
}

contract Cure {
    mapping (address => uint256) public wards;
    uint256 public live;
    address[] public sources;
    uint256 public total;
    mapping (address => uint256) public pos; // position in sources + 1, 0 means a source does not exist
    mapping (address => uint256) public amt;

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Cage();

    modifier auth {
        require(wards[msg.sender] == 1, "Cure/not-authorized");
        _;
    }

    modifier isLive {
        require(live == 1, "Cure/not-live");
        _;
    }

    // --- Internal ---
    function _add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "Cure/add-overflow");
    }

    function _sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "Cure/sub-underflow");
    }

    constructor() public {
        live = 1;
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    function count() external view returns (uint256 count_) {
        count_ = sources.length;
    }

    function list() external view returns (address[] memory) {
        return sources;
    }

    function rely(address usr) external auth isLive {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth isLive {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function addSource(address src) external auth isLive {
        require(pos[src] == 0, "Cure/already-existing-source");
        sources.push(src);
        pos[src] = sources.length;
        uint256 amt_ = amt[src] = SourceLike(src).cure();
        total = _add(total, amt_);
    }

    function delSource(address src) external auth isLive {
        uint256 pos_ = pos[src];
        require(pos_ > 0, "Cure/non-existing-source");
        uint256 last = sources.length;
        if (pos_ < last) {
            address move = sources[last - 1];
            sources[pos_ - 1] = move;
            pos[move] = pos_;
        }
        sources.pop();
        total = _sub(total, amt[src]);
        delete pos[src];
        delete amt[src];
    }

    function cage() external auth isLive {
        live = 0;
        emit Cage();
    }

    function reset(address src) external {
        uint256 oldAmt_ = amt[src];
        uint256 newAmt_ = amt[src] = SourceLike(src).cure();
        total = _add(_sub(total, oldAmt_), newAmt_);
    }
}
