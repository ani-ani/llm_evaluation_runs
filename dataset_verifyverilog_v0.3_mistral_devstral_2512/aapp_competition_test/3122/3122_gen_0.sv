module lounge_assigner (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Number of airports (1-8)
    input wire [3:0] n,
    
    // Number of routes (0-16)
    input wire [4:0] m,
    
    // Route definitions: 16 routes, each 10 bits
    // Format: [9:8] = c (constraint), [7:4] = b (airport b), [3:0] = a (airport a)
    input wire [9:0] edge_0,  edge_1,  edge_2,  edge_3,
    input wire [9:0] edge_4,  edge_5,  edge_6,  edge_7,
    input wire [9:0] edge_8,  edge_9,  edge_10, edge_11,
    input wire [9:0] edge_12, edge_13, edge_14, edge_15,
    
    // Outputs
    output reg [7:0] result,
    output reg done,
    output reg impossible
);

// State encoding
localparam [2:0] S_IDLE      = 3'b000;
localparam [2:0] S_LOAD      = 3'b001;
localparam [2:0] S_ENUMERATE = 3'b010;
localparam [2:0] S_CHECK     = 3'b011;
localparam [2:0] S_UPDATE    = 3'b100;
localparam [2:0] S_OUTPUT    = 3'b101;

reg [2:0] state, next_state;

// Edge storage (16 x 10-bit registers)
reg [9:0] edges [0:15];

// Enumeration registers
reg [7:0] assignment;      // Current assignment (8-bit mask)
reg [7:0] min_assignment;  // Best assignment found
reg [7:0] min_count;       // Minimum lounge count
reg valid_assignment;      // Current assignment validity
reg [7:0] lounge_count;    // Count of lounges in current assignment

// Edge checking registers
reg [3:0] edge_idx;        // Current edge index (0-15)
reg [3:0] airport_a;       // Extracted airport a
reg [3:0] airport_b;       // Extracted airport b
reg [1:0] constraint;      // Extracted constraint
reg bit_a, bit_b;          // Bits for airports a and b

// Load counter
reg [3:0] load_idx;

// Helper to count 1s in 8-bit value (LUT-based for speed)
function [3:0] popcount;
    input [7:0] val;
    begin
        popcount = 
            val[0] + val[1] + val[2] + val[3] + 
            val[4] + val[5] + val[6] + val[7];
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    case (state)
        S_IDLE:      next_state = start ? S_LOAD : S_IDLE;
        S_LOAD:      next_state = (load_idx == 4'd15) ? S_ENUMERATE : S_LOAD;
        S_ENUMERATE: next_state = (assignment >= (1 << n)) ? S_OUTPUT : S_CHECK;
        S_CHECK:     next_state = (edge_idx == m[3:0]) ? S_UPDATE : S_CHECK;
        S_UPDATE:    next_state = S_ENUMERATE;
        S_OUTPUT:    next_state = S_IDLE;
        default:     next_state = S_IDLE;
    endcase
end

// Datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        result <= 8'h00;
        done <= 1'b0;
        impossible <= 1'b0;
        load_idx <= 4'd0;
        assignment <= 8'h00;
        min_count <= 8'hFF;  // Initialize to max
        min_assignment <= 8'h00;
        edge_idx <= 4'd0;
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                impossible <= 1'b0;
                load_idx <= 4'd0;
                assignment <= 8'h00;
                min_count <= 8'hFF;
                min_assignment <= 8'h00;
                edge_idx <= 4'd0;
            end
            
            S_LOAD: begin
                // Store edges from input ports
                case (load_idx)
                    4'd0:  edges[0]  <= edge_0;
                    4'd1:  edges[1]  <= edge_1;
                    4'd2:  edges[2]  <= edge_2;
                    4'd3:  edges[3]  <= edge_3;
                    4'd4:  edges[4]  <= edge_4;
                    4'd5:  edges[5]  <= edge_5;
                    4'd6:  edges[6]  <= edge_6;
                    4'd7:  edges[7]  <= edge_7;
                    4'd8:  edges[8]  <= edge_8;
                    4'd9:  edges[9]  <= edge_9;
                    4'd10: edges[10] <= edge_10;
                    4'd11: edges[11] <= edge_11;
                    4'd12: edges[12] <= edge_12;
                    4'd13: edges[13] <= edge_13;
                    4'd14: edges[14] <= edge_14;
                    4'd15: edges[15] <= edge_15;
                endcase
                load_idx <= load_idx + 1'b1;
            end
            
            S_ENUMERATE: begin
                // Start checking next assignment
                if (assignment < (1 << n)) begin
                    assignment <= assignment + 1'b1;
                    edge_idx <= 4'd0;
                    valid_assignment <= 1'b1;
                    lounge_count <= popcount(assignment);
                end
            end
            
            S_CHECK: begin
                // Extract current edge
                airport_a <= edges[edge_idx][3:0];
                airport_b <= edges[edge_idx][7:4];
                constraint <= edges[edge_idx][9:8];
                
                // Get bits for these airports from assignment
                // Note: airports are 1-indexed, so subtract 1
                bit_a <= assignment[airport_a - 1'b1];
                bit_b <= assignment[airport_b - 1'b1];
                
                // Check constraint on next cycle
                edge_idx <= edge_idx + 1'b1;
            end
            
            S_UPDATE: begin
                // Check if constraint was satisfied
                case (constraint)
                    2'b00: begin // Both 0
                        if (bit_a || bit_b) valid_assignment <= 1'b0;
                    end
                    2'b01: begin // Exactly one 1
                        if (bit_a == bit_b) valid_assignment <= 1'b0;
                    end
                    2'b10: begin // Both 1 (note: c=2 is binary 10)
                        if (!bit_a || !bit_b) valid_assignment <= 1'b0;
                    end
                    default: valid_assignment <= 1'b0;
                endcase
                
                // If valid and better than min, update
                if (valid_assignment && lounge_count < min_count) begin
                    min_count <= lounge_count;
                    min_assignment <= assignment;
                end
            end
            
            S_OUTPUT: begin
                done <= 1'b1;
                if (min_count == 8'hFF) begin
                    impossible <= 1'b1;
                    result <= 8'h00;
                end else begin
                    impossible <= 1'b0;
                    result <= min_count;
                end
            end
        endcase
    end
end

endmodule