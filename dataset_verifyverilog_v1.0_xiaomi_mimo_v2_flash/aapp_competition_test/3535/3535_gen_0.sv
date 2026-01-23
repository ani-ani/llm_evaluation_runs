module quantum_chip_solver #(
    parameter MAX_K = 8,
    parameter DATA_WIDTH = 4,
    parameter SPIN_WIDTH = 1,
    parameter RESULT_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [DATA_WIDTH-1:0] N,
    input wire [DATA_WIDTH-1:0] M,
    input wire [DATA_WIDTH-1:0] K,
    
    // Measurement inputs: up to MAX_K measurements
    input wire [DATA_WIDTH-1:0] y_0, x_0,
    input wire [SPIN_WIDTH-1:0] s_0,
    input wire [DATA_WIDTH-1:0] y_1, x_1,
    input wire [SPIN_WIDTH-1:0] s_1,
    input wire [DATA_WIDTH-1:0] y_2, x_2,
    input wire [SPIN_WIDTH-1:0] s_2,
    input wire [DATA_WIDTH-1:0] y_3, x_3,
    input wire [SPIN_WIDTH-1:0] s_3,
    input wire [DATA_WIDTH-1:0] y_4, x_4,
    input wire [SPIN_WIDTH-1:0] s_4,
    input wire [DATA_WIDTH-1:0] y_5, x_5,
    input wire [SPIN_WIDTH-1:0] s_5,
    input wire [DATA_WIDTH-1:0] y_6, x_6,
    input wire [SPIN_WIDTH-1:0] s_6,
    input wire [DATA_WIDTH-1:0] y_7, x_7,
    input wire [SPIN_WIDTH-1:0] s_7,
    
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE    = 3'd0;
localparam [2:0] PROCESS = 3'd1;
localparam [2:0] COUNT   = 3'd2;
localparam [2:0] FINISH  = 3'd3;

// Node ID: rows 0..N-1, columns N..N+M-1
// Max nodes = 16 (8+8)
localparam NODE_WIDTH = 4;

// Union-Find structures
reg [NODE_WIDTH-1:0] parent [0:15];
reg [1:0] parity [0:15];

// Current state
reg [2:0] state;
reg [3:0] idx; // Measurement index (0 to K-1)
reg [3:0] node_idx; // For counting roots
reg [3:0] root_count;
reg inconsistency_flag;

// Temporary variables for find operation
reg [NODE_WIDTH-1:0] find_node;
wire [NODE_WIDTH-1:0] find_root;
wire [1:0] find_parity;

// Function to find root and parity (combinational)
function automatic void find_root_func(
    input [NODE_WIDTH-1:0] node,
    output [NODE_WIDTH-1:0] root,
    output [1:0] parity_out
);
    reg [NODE_WIDTH-1:0] current;
    reg [NODE_WIDTH-1:0] temp_parent;
    reg [1:0] accum_parity;
    integer i;
    begin
        current = node;
        accum_parity = 2'd0;
        for (i = 0; i < 16; i = i + 1) begin
            temp_parent = parent[current];
            if (temp_parent == current) begin
                // Reached root
                root = current;
                parity_out = accum_parity;
                return;
            end
            accum_parity = accum_parity ^ parity[current];
            current = temp_parent;
        end
        // Should not reach here
        root = node;
        parity_out = 2'd0;
    end
endfunction

// Get measurement data based on index
reg [DATA_WIDTH-1:0] cur_y;
reg [DATA_WIDTH-1:0] cur_x;
reg [SPIN_WIDTH-1:0] cur_s;

always @(*) begin
    case (idx)
        4'd0: begin cur_y = y_0; cur_x = x_0; cur_s = s_0; end
        4'd1: begin cur_y = y_1; cur_x = x_1; cur_s = s_1; end
        4'd2: begin cur_y = y_2; cur_x = x_2; cur_s = s_2; end
        4'd3: begin cur_y = y_3; cur_x = x_3; cur_s = s_3; end
        4'd4: begin cur_y = y_4; cur_x = x_4; cur_s = s_4; end
        4'd5: begin cur_y = y_5; cur_x = x_5; cur_s = s_5; end
        4'd6: begin cur_y = y_6; cur_x = x_6; cur_s = s_6; end
        4'd7: begin cur_y = y_7; cur_x = x_7; cur_s = s_7; end
        default: begin cur_y = 4'd0; cur_x = 4'd0; cur_s = 1'd0; end
    endcase
end

// Find root and parity for current nodes
reg [NODE_WIDTH-1:0] u_root;
reg [1:0] u_parity;
reg [NODE_WIDTH-1:0] v_root;
reg [1:0] v_parity;

always @(*) begin
    find_root_func(cur_y, u_root, u_parity);
    find_root_func(N + cur_x, v_root, v_parity);
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
        idx <= 4'd0;
        node_idx <= 4'd0;
        root_count <= 4'd0;
        inconsistency_flag <= 1'b0;
        // Initialize union-find structures
        for (integer i = 0; i < 16; i = i + 1) begin
            parent[i] <= i[3:0];
            parity[i] <= 2'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                idx <= 4'd0;
                node_idx <= 4'd0;
                root_count <= 4'd0;
                inconsistency_flag <= 1'b0;
                // Reset union-find structures
                for (integer i = 0; i < 16; i = i + 1) begin
                    parent[i] <= i[3:0];
                    parity[i] <= 2'd0;
                end
                if (start) begin
                    state <= PROCESS;
                end
            end
            
            PROCESS: begin
                if (idx < K) begin
                    // Process measurement idx
                    if (u_root == v_root) begin
                        // Same set: check parity
                        if ((u_parity ^ v_parity) != {1'b0, cur_s}) begin
                            inconsistency_flag <= 1'b1;
                        end
                    end else begin
                        // Union operation
                        // Attach root of u to root of v
                        parent[u_root] <= v_root;
                        parity[u_root] <= u_parity ^ v_parity ^ {1'b0, cur_s};
                    end
                    idx <= idx + 4'd1;
                end else begin
                    // All measurements processed
                    if (inconsistency_flag) begin
                        state <= FINISH;
                        result <= 32'd0;
                    end else begin
                        state <= COUNT;
                        node_idx <= 4'd0;
                        root_count <= 4'd0;
                    end
                end
            end
            
            COUNT: begin
                if (node_idx < (N + M)) begin
                    // Check if node is a root (parent == itself)
                    if (parent[node_idx] == node_idx) begin
                        root_count <= root_count + 4'd1;
                    end
                    node_idx <= node_idx + 4'd1;
                end else begin
                    // Finished counting
                    // result = 2^(root_count - 1)
                    case (root_count)
                        4'd2: result <= 32'd1;      // 2^1
                        4'd3: result <= 32'd2;      // 2^2
                        4'd4: result <= 32'd4;      // 2^3
                        4'd5: result <= 32'd8;      // 2^4
                        4'd6: result <= 32'd16;     // 2^5
                        4'd7: result <= 32'd32;     // 2^6
                        4'd8: result <= 32'd64;     // 2^7
                        4'd9: result <= 32'd128;    // 2^8
                        4'd10: result <= 32'd256;   // 2^9
                        4'd11: result <= 32'd512;   // 2^10
                        4'd12: result <= 32'd1024;  // 2^11
                        4'd13: result <= 32'd2048;  // 2^12
                        4'd14: result <= 32'd4096;  // 2^13
                        4'd15: result <= 32'd8192;  // 2^14
                        4'd16: result <= 32'd16384; // 2^15
                        default: result <= 32'd0;
                    endcase
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule