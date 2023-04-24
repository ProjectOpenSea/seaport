//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum OffererZoneFailureReason {
    None,
    ContractOfferer_generateReverts, // Offerer generateOrder reverts
    ContractOfferer_generateReturnsInvalidEncoding, // Bad encoding
    ContractOfferer_ratifyReverts, // Offerer ratifyOrder reverts
    ContractOfferer_InsufficientMinimumReceived, // too few minimum received items
    ContractOfferer_IncorrectMinimumReceived, // incorrect (insufficient amount, wrong token, etc.) minimum received items
    ContractOfferer_ExcessMaximumSpent, // too many maximum spent items
    ContractOfferer_IncorrectMaximumSpent, // incorrect (too many, wrong token, etc.) maximum spent items
    ContractOfferer_InvalidMagicValue, // Offerer did not return correct magic value
    Zone_reverts, // Zone validateOrder call reverts
    Zone_InvalidMagicValue // Zone validateOrder call returns invalid magic value
}
