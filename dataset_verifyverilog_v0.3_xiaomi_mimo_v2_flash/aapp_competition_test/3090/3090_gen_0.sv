module wireless_coverage (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,        // number of rows (1..4)
    input wire [3:0] M,        // number of columns (1..4)
    input wire [7:0] K,        // cost of each cellular hub
    // Cost matrix for 4x4 grid, row-major order. For unused cells set any value.
    input wire [7:0] cost00, cost01, cost02, cost03,
    input wire [7:0] cost10, cost11, cost12, cost13,
    input wire [7:0] cost20, cost21, cost22, cost23,
    input wire [7:0] cost30, cost31, cost32, cost33,
    output reg [15:0] result,
    output reg done
);

// Constants
localparam [2:0] IDLE = 3'b000;
localparam [2:0] INIT = 3'b001;
localparam [2:0] CALC = 3'b010;
localparam [2:0] COMPARE = 3'b011;
localparam [2:0] INCR = 3'b100;
localparam [2:0] DONE = 3'b101;
localparam [15:0] HUGE_PENALTY = 16'd10000;
localparam [15:0] MAX_COUNTER = 16'd65535;

// Registers
reg [2:0] state;
reg [15:0] conf;          // current configuration (16 bits)
reg [15:0] counter;       // enumeration counter (0..65535)
reg [15:0] min_cost;
reg [15:0] router_sum;
reg [15:0] edge_sum;
reg [15:0] total_cost;
reg [3:0] row_idx, col_idx;
reg phase;                // 0: router sum, 1: edge sum
reg edge_type;            // 0: horizontal, 1: vertical
reg [7:0] cost_reg [0:15]; // stored costs
reg [2:0] calc_substate;  // Substate for CALC phase

// Helper wires
wire [3:0] pos;
wire [15:0] valid_mask;
wire conf_bit_at_pos;

// Helper to compute position in flattened array
assign pos = (row_idx * M) + col_idx;

// Extract specific bit for neighbor comparison
assign conf_bit_at_pos = conf[pos];

// Compute mask for valid cells (lower N*M bits set)
always @(*) begin
    case (N * M)
        4'd1:  valid_mask = 16'h0001;
        4'd2:  valid_mask = 16'h0003;
        4'd3:  valid_mask = 16'h0007;
        4'd4:  valid_mask = 16'h000F;
        4'd5:  valid_mask = 16'h001F;
        4'd6:  valid_mask = 16'h003F;
        4'd7:  valid_mask = 16'h007F;
        4'd8:  valid_mask = 16'h00FF;
        4'd9:  valid_mask = 16'h01FF;
        4'd10: valid_mask = 16'h03FF;
        4'd11: valid_mask = 16'h07FF;
        4'd12: valid_mask = 16'h0FFF;
        4'd13: valid_mask = 16'h1FFF;
        4'd14: valid_mask = 16'h3FFF;
        4'd15: valid_mask = 16'h7FFF;
        4'd16: valid_mask = 16'hFFFF;
        default: valid_mask = 16'hFFFF;
    endcase
end

// State transition and sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 0;
        counter <= 0;
        min_cost <= 16'hFFFF;
        conf <= 0;
        router_sum <= 0;
        edge_sum <= 0;
        total_cost <= 0;
        row_idx <= 0;
        col_idx <= 0;
        phase <= 0;
        edge_type <= 0;
        calc_substate <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    // Load inputs
                    cost_reg[0] <= cost00; cost_reg[1] <= cost01; cost_reg[2] <= cost02; cost_reg[3] <= cost03;
                    cost_reg[4] <= cost10; cost_reg[5] <= cost11; cost_reg[6] <= cost12; cost_reg[7] <= cost13;
                    cost_reg[8] <= cost20; cost_reg[9] <= cost21; cost_reg[10] <= cost22; cost_reg[11] <= cost23;
                    cost_reg[12] <= cost30; cost_reg[13] <= cost31; cost_reg[14] <= cost32; cost_reg[15] <= cost33;
                    counter <= 0;
                    min_cost <= 16'hFFFF;
                    done <= 0;
                    state <= INIT;
                end
            end

            INIT: begin
                // Prepare for cost calculation of current configuration
                conf <= counter;  // current configuration
                router_sum <= 0;
                edge_sum <= 0;
                row_idx <= 0;
                col_idx <= 0;
                phase <= 0;       // start with router sum
                edge_type <= 0;
                calc_substate <= 0;
                state <= CALC;
            end

            CALC: begin
                if (phase == 0) begin // Router sum
                    if (row_idx < N) begin
                        if (col_idx < M) begin
                            // Add cost if router installed at this valid cell
                            if (conf[pos]) begin
                                router_sum <= router_sum + cost_reg[pos];
                            end
                            col_idx <= col_idx + 1;
                        end else begin
                            // Next row
                            col_idx <= 0;
                            row_idx <= row_idx + 1;
                        end
                    end else begin
                        // All valid cells processed; now check for invalid routers
                        if (conf & ~valid_mask) begin
                            router_sum <= router_sum + HUGE_PENALTY;
                        end
                        // Switch to edge phase
                        phase <= 1;
                        edge_type <= 0; // horizontal edges first
                        row_idx <= 0;
                        col_idx <= 0;
                    end
                end else begin // Edge sum
                    if (edge_type == 0) begin // horizontal edges
                        if (row_idx < N && col_idx < (M - 1)) begin
                            // Compare bits of two adjacent cells
                            // Need to calculate positions manually to avoid unpacked array issues in combinational logic
                            if (conf[(row_idx * M) + col_idx] == conf[(row_idx * M) + col_idx + 1]) begin
                                edge_sum <= edge_sum + K;
                            end
                            col_idx <= col_idx + 1;
                        end else begin
                            if (col_idx >= (M - 1)) begin
                                col_idx <= 0;
                                row_idx <= row_idx + 1;
                            end
                            if (row_idx >= N) begin
                                // Horizontal done, switch to vertical
                                edge_type <= 1;
                                row_idx <= 0;
                                col_idx <= 0;
                            end
                        end
                    end else begin // vertical edges
                        if (row_idx < (N - 1) && col_idx < M) begin
                            if (conf[(row_idx * M) + col_idx] == conf[((row_idx + 1) * M) + col_idx]) begin
                                edge_sum <= edge_sum + K;
                            end
                            col_idx <= col_idx + 1;
                        end else begin
                            if (col_idx >= M) begin
                                col_idx <= 0;
                                row_idx <= row_idx + 1;
                            end
                            if (row_idx >= (N - 1)) begin
                                // All edges done, compute total cost
                                total_cost <= router_sum + edge_sum;
                                state <= COMPARE;
                            end
                        end
                    end
                end
            end

            COMPARE: begin
                if (total_cost < min_cost) begin
                    min_cost <= total_cost;
                end
                state <= INCR;
            end

            INCR: begin
                if (counter == MAX_COUNTER) begin // wrapped around after 65535 -> 0, done
                    state <= DONE;
                end else begin
                    counter <= counter + 1;
                    state <= INIT; // next configuration
                end
            end

            DONE: begin
                result <= min_cost;
                done <= 1;
                // Stay in DONE until reset
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule