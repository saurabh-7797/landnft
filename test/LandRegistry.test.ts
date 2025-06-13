import { expect } from "chai";
import { ethers } from "hardhat";
import { LandRegistry } from "../typechain-types";
import { ZeroAddress, keccak256, toUtf8Bytes } from "ethers";

// Constants
const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
const INVALID_ROLE = keccak256(toUtf8Bytes("INVALID_ROLE"));
const CLERK_ROLE = "0xd603cc2d39ea2ab57038652f29ac8e7fd0e40e6a9b0f81de9bbc4acc6780d962";
const PATWARI_ROLE = "0x50e703f531f689b5209659789301bd8162e21f9ce29645e21388467925e31cc4";
const TEHSILDAR_ROLE = "0x25e4229ee368ad63b1bdff8c00b38fac6bfb78fbb3fe3aae36beb769834e77a3";

// Helper function to create boxed console output
function logBox(title: string, content: string) {
    const width = 80;
    const horizontalLine = "─".repeat(width - 2);
    const emptyLine = " ".repeat(width - 2);
    
    console.log(`\n┌${horizontalLine}┐`);
    console.log(`│ ${title.padEnd(width - 4)} │`);
    console.log(`├${horizontalLine}┤`);
    console.log(`│${emptyLine}│`);
    
    content.split('\n').forEach(line => {
        console.log(`│ ${line.padEnd(width - 4)} │`);
    });
    
    console.log(`│${emptyLine}│`);
    console.log(`└${horizontalLine}┘\n`);
}

describe("LandRegistry", function () {
    let landRegistry: LandRegistry;
    let owner: any;
    let patwari: any;
    let clerk: any;
    let tehsildar: any;
    let seller: any;
    let buyer: any;
    let other: any;

    beforeEach(async function () {
        [owner, patwari, clerk, tehsildar, seller, buyer, other] = await ethers.getSigners();
        
        const LandRegistry = await ethers.getContractFactory("LandRegistry");
        landRegistry = await LandRegistry.deploy();
        await landRegistry.waitForDeployment();
        
        // Register officials
        await landRegistry.registerOfficial(
            "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
            patwari.address,
            PATWARI_ROLE,
            "123456789012"
        );
        
        await landRegistry.registerOfficial(
            "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
            clerk.address,
            CLERK_ROLE,
            "123456789013"
        );
        
        await landRegistry.registerOfficial(
            "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
            tehsildar.address,
            TEHSILDAR_ROLE,
            "123456789014"
        );
        
        // Register owners
        await landRegistry.connect(seller).registerOwner(
            "Test Seller",
            "1234567890",
            "123456789012",
            "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
        );
        
        await landRegistry.connect(buyer).registerOwner(
            "Test Buyer",
            "9876543210",
            "987654321098",
            "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
        );
    });

    describe("Role Management", function () {
        it("Should have correct roles assigned to deployer", async function () {
            logBox("Test: Role Assignment",
                `Input:\n` +
                `- Deployer Address: ${owner.address}\n\n` +
                `Expected Output:\n` +
                `- DEFAULT_ADMIN_ROLE: true\n` +
                `- PATWARI_ROLE: true\n` +
                `- CLERK_ROLE: true\n` +
                `- TEHSILDAR_ROLE: true`
            );

            expect(await landRegistry.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
            expect(await landRegistry.hasRole(PATWARI_ROLE, owner.address)).to.be.true;
            expect(await landRegistry.hasRole(CLERK_ROLE, owner.address)).to.be.true;
            expect(await landRegistry.hasRole(TEHSILDAR_ROLE, owner.address)).to.be.true;
        });

        it("Should fail to assign invalid role", async function () {
            await expect(
                landRegistry.connect(other).grantRole(INVALID_ROLE, other.address)
            ).to.be.revertedWith(
                "AccessControl: account " + other.address.toLowerCase() + " is missing role " + DEFAULT_ADMIN_ROLE
            );
        });
    });

    describe("Official Management", function () {
        it("Should register a new official", async function () {
            logBox("Test: Register New Official",
                `Input:\n` +
                `- IPFS Hash: QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco\n` +
                `- Address: ${other.address}\n` +
                `- Role: PATWARI_ROLE\n` +
                `- Aadhar: 123456789016\n\n` +
                `Expected Output:\n` +
                `- Official registered successfully\n` +
                `- Role assigned correctly`
            );

            await landRegistry.registerOfficial(
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
                other.address,
                PATWARI_ROLE,
                "123456789016"
            );

            const official = await landRegistry.getOfficialByAddress(other.address);
            expect(official.role).to.equal(PATWARI_ROLE);
            expect(official.aadharCardNumber).to.equal("123456789016");
        });

        it("Should fail to register official with zero address", async function () {
            logBox("Test: Register Official with Zero Address",
                `Input:\n` +
                `- Address: Zero Address\n` +
                `- Role: PATWARI_ROLE\n\n` +
                `Expected Output:\n` +
                `- Error: ZeroAddress`
            );

            await expect(
                landRegistry.registerOfficial(
                    "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
                    ZeroAddress,
                    PATWARI_ROLE,
                    "123456789016"
                )
            ).to.be.revertedWithCustomError(landRegistry, "ZeroAddress");
        });

        it("Should fail to register official with invalid role", async function () {
            logBox("Test: Register Official with Invalid Role",
                `Input:\n` +
                `- Address: ${other.address}\n` +
                `- Role: INVALID_ROLE\n\n` +
                `Expected Output:\n` +
                `- Error: InvalidRole`
            );

            await expect(
                landRegistry.registerOfficial(
                    "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
                    other.address,
                    INVALID_ROLE,
                    "123456789016"
                )
            ).to.be.revertedWithCustomError(landRegistry, "InvalidRole");
        });

        it("Should update official details", async function () {
            logBox("Test: Update Official Details",
                `Input:\n` +
                `- Official ID: 1\n` +
                `- New IPFS Hash: QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco\n` +
                `- Active: false\n\n` +
                `Expected Output:\n` +
                `- IPFS Hash updated\n` +
                `- Active status updated`
            );

            await landRegistry.updateOfficial(
                1,
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
                false
            );

            const official = await landRegistry.getOfficial(1);
            expect(official.ipfsHash).to.equal("QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco");
            expect(official.active).to.be.false;
        });

        it("Should fail to update non-existent official", async function () {
            logBox("Test: Update Non-existent Official",
                `Input:\n` +
                `- Official ID: 999\n` +
                `- New IPFS Hash: QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco\n\n` +
                `Expected Output:\n` +
                `- Error: OfficialDoesNotExist`
            );

            await expect(
                landRegistry.updateOfficial(
                    999,
                    "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
                    true
                )
            ).to.be.revertedWithCustomError(landRegistry, "OfficialDoesNotExist");
        });
    });

    describe("Owner Management", function () {
        it("Should register a new owner", async function () {
            logBox("Test: Register New Owner",
                `Input:\n` +
                `- Name: New Owner\n` +
                `- Contact: 5555555555\n` +
                `- Aadhar: 555555555555\n` +
                `- IPFS Hash: QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco\n\n` +
                `Expected Output:\n` +
                `- Owner registered successfully\n` +
                `- Details stored correctly`
            );

            await landRegistry.connect(other).registerOwner(
                "New Owner",
                "5555555555",
                "555555555555",
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            const owner = await landRegistry.getOwner(other.address);
            expect(owner.name).to.equal("New Owner");
            expect(owner.contactNumber).to.equal("5555555555");
            expect(owner.aadharNumber).to.equal("555555555555");
        });

        it("Should fail to register owner with empty name", async function () {
            logBox("Test: Register Owner with Empty Name",
                `Input:\n` +
                `- Name: (empty)\n` +
                `- Contact: 5555555555\n` +
                `- Aadhar: 555555555555\n\n` +
                `Expected Output:\n` +
                `- Error: NameEmpty`
            );

            await expect(
                landRegistry.connect(other).registerOwner(
                    "",
                    "5555555555",
                    "555555555555",
                    "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
                )
            ).to.be.revertedWithCustomError(landRegistry, "NameEmpty");
        });

        it("Should fail to register owner with empty aadhar", async function () {
            logBox("Test: Register Owner with Empty Aadhar",
                `Input:\n` +
                `- Name: New Owner\n` +
                `- Contact: 5555555555\n` +
                `- Aadhar: (empty)\n\n` +
                `Expected Output:\n` +
                `- Error: AadharEmpty`
            );

            await expect(
                landRegistry.connect(other).registerOwner(
                    "New Owner",
                    "5555555555",
                    "",
                    "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
                )
            ).to.be.revertedWithCustomError(landRegistry, "AadharEmpty");
        });

        it("Should update owner details", async function () {
            logBox("Test: Update Owner Details",
                `Input:\n` +
                `- Name: Updated Seller\n` +
                `- Contact: 1111111111\n` +
                `- IPFS Hash: QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco\n\n` +
                `Expected Output:\n` +
                `- Name updated\n` +
                `- Contact updated\n` +
                `- IPFS Hash updated`
            );

            await landRegistry.connect(seller).updateOwner(
                "Updated Seller",
                "1111111111",
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            const owner = await landRegistry.getOwner(seller.address);
            expect(owner.name).to.equal("Updated Seller");
            expect(owner.contactNumber).to.equal("1111111111");
        });

        it("Should fail to update non-existent owner", async function () {
            logBox("Test: Update Non-existent Owner",
                `Input:\n` +
                `- Address: ${other.address} (not registered)\n` +
                `- Name: New Name\n` +
                `- Contact: 9999999999\n\n` +
                `Expected Output:\n` +
                `- Error: NotRegisteredOwner`
            );

            await expect(
                landRegistry.connect(other).updateOwner(
                    "New Name",
                    "9999999999",
                    "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
                )
            ).to.be.revertedWithCustomError(landRegistry, "NotRegisteredOwner");
        });
    });

    describe("Land Registration", function () {
        it("Should create a land draft", async function () {
            logBox("Test: Create Land Draft",
                `Input:\n` +
                `- State: State\n` +
                `- District: District\n` +
                `- Village: Village\n` +
                `- Khasra Number: K123\n` +
                `- Area: 1000\n` +
                `- Land Type: Agricultural\n` +
                `- Owner: ${seller.address}\n` +
                `- IPFS Hash: QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco\n\n` +
                `Expected Output:\n` +
                `- Khasra Number: K123\n` +
                `- Current Owner: ${seller.address}\n` +
                `- Status: PENDING (0)`
            );

            await landRegistry.connect(patwari).createLandDraft(
                "State",
                "District",
                "Village",
                "K123",
                1000,
                "Agricultural",
                seller.address,
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            const draft = await landRegistry.getLandDraft(0);
            expect(draft.khasraNumber).to.equal("K123");
            expect(draft.currentOwner).to.equal(seller.address);
            expect(draft.status).to.equal(0); // PENDING
        });

        it("Should fail to create draft with existing khasra number", async function () {
            // First create a draft
            await landRegistry.connect(patwari).createLandDraft(
                "State",
                "District",
                "Village",
                "K123",
                1000,
                "Agricultural",
                seller.address,
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            // Try to create another draft with the same khasra number
            await expect(
                landRegistry.connect(patwari).createLandDraft(
                    "State",
                    "District",
                    "Village",
                    "K123",
                    1000,
                    "Agricultural",
                    seller.address,
                    "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
                )
            ).to.be.revertedWithCustomError(landRegistry, "KhasraNumberExists");
        });

        it("Should approve draft as owner", async function () {
            logBox("Test: Approve Draft as Owner",
                `Input:\n` +
                `- Khasra Number: K124\n` +
                `- Owner: ${seller.address}\n\n` +
                `Expected Output:\n` +
                `- Owner Approved: true\n` +
                `- Status: MINTED (4)`
            );

            await landRegistry.connect(patwari).createLandDraft(
                "State",
                "District",
                "Village",
                "K124",
                1000,
                "Agricultural",
                seller.address,
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            await landRegistry.connect(seller).approveDraftAsOwner(0);

            const draft = await landRegistry.getLandDraft(0);
            expect(draft.ownerApproved).to.be.true;
            expect(draft.status).to.equal(4); // MINTED
        });

        it("Should fail to approve draft if not owner", async function () {
            // Create a draft
            await landRegistry.connect(patwari).createLandDraft(
                "State",
                "District",
                "Village",
                "K125",
                1000,
                "Agricultural",
                seller.address,
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            // Try to approve as non-owner
            await expect(
                landRegistry.connect(other).approveDraftAsOwner(0)
            ).to.be.revertedWithCustomError(landRegistry, "NotOwner");
        });

        it("Should reject draft with reason", async function () {
            logBox("Test: Reject Draft with Reason",
                `Input:\n` +
                `- Khasra Number: K126\n` +
                `- Owner: ${seller.address}\n` +
                `- Rejector: ${tehsildar.address}\n` +
                `- Reason: Incomplete documents\n\n` +
                `Expected Output:\n` +
                `- Status: REJECTED (3)`
            );

            await landRegistry.connect(patwari).createLandDraft(
                "State",
                "District",
                "Village",
                "K126",
                1000,
                "Agricultural",
                seller.address,
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            await landRegistry.connect(tehsildar).rejectDraft(0, "Incomplete documents");

            const draft = await landRegistry.getLandDraft(0);
            expect(draft.status).to.equal(3); // REJECTED
        });

        it("Should fail to reject draft if not authorized", async function () {
            logBox("Test: Fail to Reject Draft if Not Authorized",
                `Input:\n` +
                `- Khasra Number: K127\n` +
                `- Owner: ${seller.address}\n` +
                `- Rejector: ${other.address} (not authorized)\n` +
                `- Reason: Invalid reason\n\n` +
                `Expected Output:\n` +
                `- Error: AccessControl: account ${other.address.toLowerCase()} is missing role ${TEHSILDAR_ROLE}`
            );

            await landRegistry.connect(patwari).createLandDraft(
                "State",
                "District",
                "Village",
                "K127",
                1000,
                "Agricultural",
                seller.address,
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            await expect(
                landRegistry.connect(other).rejectDraft(0, "Invalid reason")
            ).to.be.revertedWith("AccessControl: account " + other.address.toLowerCase() + " is missing role " + TEHSILDAR_ROLE);
        });
    });

    describe("Transfer Process", function () {
        beforeEach(async function () {
            logBox("Setting up Transfer Process Test",
                "Creating and approving a draft first..."
            );

            await landRegistry.connect(patwari).createLandDraft(
                "State",
                "District",
                "Village",
                "K128",
                1000,
                "Agricultural",
                seller.address,
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            await landRegistry.connect(seller).approveDraftAsOwner(0);
        });

        it("Should initiate transfer", async function () {
            logBox("Test: Initiate Transfer",
                `Input:\n` +
                `- Token ID: 0\n` +
                `- Current Owner: ${seller.address}\n` +
                `- New Owner: ${buyer.address}\n` +
                `- Property Address: Property Address\n` +
                `- Property Type: Residential\n` +
                `- IPFS Hash: QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco\n\n` +
                `Expected Output:\n` +
                `- Token ID: 0\n` +
                `- New Owner: ${buyer.address}\n` +
                `- Status: PENDING (0)`
            );

            await landRegistry.connect(seller).initiateTransfer(
                0,
                buyer.address,
                "Property Address",
                "Residential",
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
                false,
                false
            );

            const transfer = await landRegistry.getTransferRequest(0);
            expect(transfer.tokenId).to.equal(0);
            expect(transfer.newOwner).to.equal(buyer.address);
            expect(transfer.status).to.equal(0); // PENDING
        });

        it("Should fail to initiate transfer if not owner", async function () {
            logBox("Test: Fail to Initiate Transfer if Not Owner",
                `Input:\n` +
                `- Token ID: 0\n` +
                `- Current Owner: ${seller.address}\n` +
                `- Initiator: ${other.address} (not the owner)\n` +
                `- New Owner: ${buyer.address}\n\n` +
                `Expected Output:\n` +
                `- Error: NotTheOwner`
            );

            await expect(
                landRegistry.connect(other).initiateTransfer(
                    0,
                    buyer.address,
                    "Property Address",
                    "Residential",
                    "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
                    false,
                    false
                )
            ).to.be.revertedWithCustomError(landRegistry, "NotTheOwner");
        });

        it("Should fail to initiate transfer to zero address", async function () {
            logBox("Test: Fail to Initiate Transfer to Zero Address",
                `Input:\n` +
                `- Token ID: 0\n` +
                `- Current Owner: ${seller.address}\n` +
                `- New Owner: Zero Address\n\n` +
                `Expected Output:\n` +
                `- Error: ZeroAddress`
            );

            await expect(
                landRegistry.connect(seller).initiateTransfer(
                    0,
                    ZeroAddress,
                    "Property Address",
                    "Residential",
                    "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
                    false,
                    false
                )
            ).to.be.revertedWithCustomError(landRegistry, "ZeroAddress");
        });
    });

    describe("View Functions", function () {
        beforeEach(async function () {
            logBox("Setting up View Functions Test",
                "Creating and approving a draft first..."
            );

            await landRegistry.connect(patwari).createLandDraft(
                "State",
                "District",
                "Village",
                "K129",
                1000,
                "Agricultural",
                seller.address,
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
            );

            await landRegistry.connect(seller).approveDraftAsOwner(0);
        });

        it("Should get owner drafts", async function () {
            logBox("Test: Get Owner Drafts",
                `Input:\n` +
                `- Owner: ${seller.address}\n\n` +
                `Expected Output:\n` +
                `- Number of Drafts: 1\n` +
                `- Draft ID: 0`
            );

            const drafts = await landRegistry.getOwnerDrafts(seller.address);
            expect(drafts.length).to.equal(1);
            expect(drafts[0]).to.equal(0);
        });

        it("Should get draft status", async function () {
            logBox("Test: Get Draft Status",
                `Input:\n` +
                `- Draft ID: 0\n\n` +
                `Expected Output:\n` +
                `- Status: MINTED`
            );

            const status = await landRegistry.getDraftStatus(0);
            expect(status).to.equal("MINTED");
        });

        it("Should get transfer status", async function () {
            logBox("Test: Get Transfer Status",
                `Input:\n` +
                `- Token ID: 0\n` +
                `- New Owner: ${buyer.address}\n\n` +
                `Expected Output:\n` +
                `- Status: PENDING`
            );

            await landRegistry.connect(seller).initiateTransfer(
                0,
                buyer.address,
                "Property Address",
                "Residential",
                "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco",
                false,
                false
            );

            const status = await landRegistry.getTransferStatus(0);
            expect(status).to.equal("PENDING");
        });

        it("Should get owner details", async function () {
            logBox("Test: Get Owner Details",
                `Input:\n` +
                `- Owner Address: ${seller.address}\n\n` +
                `Expected Output:\n` +
                `- Name: Test Seller\n` +
                `- Contact: 1234567890\n` +
                `- Aadhar: 123456789012`
            );

            const owner = await landRegistry.getOwner(seller.address);
            expect(owner.name).to.equal("Test Seller");
            expect(owner.contactNumber).to.equal("1234567890");
            expect(owner.aadharNumber).to.equal("123456789012");
        });

        it("Should get official details", async function () {
            logBox("Test: Get Official Details",
                `Input:\n` +
                `- Official Address: ${patwari.address}\n\n` +
                `Expected Output:\n` +
                `- Role: PATWARI_ROLE\n` +
                `- Aadhar: 123456789012\n` +
                `- Active: true`
            );

            const official = await landRegistry.getOfficialByAddress(patwari.address);
            expect(official.role).to.equal(PATWARI_ROLE);
            expect(official.aadharCardNumber).to.equal("123456789012");
            expect(official.active).to.be.true;
        });
    });
});