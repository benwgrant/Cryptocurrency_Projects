// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import "./IGradebook.sol";

contract Gradebook is IGradebook {

    mapping (address => bool) public override tas;
    mapping (uint => string) public override assignment_names;
    mapping (uint => uint) public override max_scores;
    mapping (uint => mapping (string => uint)) public override scores;

    address public override instructor;
    uint public override num_assignments;

    constructor() {
        instructor = msg.sender;
    }

    function designateTA(address ta) external override {
        require(msg.sender == instructor || tas[msg.sender] == true, "Only the instructor or a TA can designate a TA");
        tas[ta] = true;
    }

    function addAssignment(string memory name, uint max_score) external override returns (uint) {
        require(msg.sender == instructor || tas[msg.sender] == true, "Only the instructor or a TA can add an assignment");
        require(max_score > 0, "Max score must be greater than 0");
        num_assignments++;
        assignment_names[num_assignments] = name;
        max_scores[num_assignments] = max_score;
        emit assignmentCreationEvent(num_assignments);
        return num_assignments;
    }

    function addGrade(string memory student, uint assignment, uint score) external override {
        require(msg.sender == instructor || tas[msg.sender] == true, "Only the instructor or a TA can add a grade");
        require(assignment <= num_assignments, "Assignment does not exist");
        require(score <= max_scores[assignment], "Score cannot be greater than max score");
        scores[assignment][student] = score;
        emit gradeEntryEvent(assignment);
    }

    function getAverage(string memory student) external override view returns (uint) {
        require(msg.sender == instructor || tas[msg.sender] == true, "Only the instructor or a TA can get the average");
        uint total = 0;
        uint max_total = 0;
        for (uint i = 1; i <= num_assignments; i++) {
            total += scores[i][student];
            max_total += max_scores[i];
        }
        return (total * 10000) / max_total;
    }

    function requestTAAccess() external override {
        require(msg.sender != instructor, "The instructor cannot request TA access");
        tas[msg.sender] = true;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IGradebook).interfaceId || interfaceId == 0x01ffc9a7;
    }





}