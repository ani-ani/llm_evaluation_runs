module indoorienteering (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] L,
    input [7:0] dist_00, dist_01, dist_02, dist_03,
    input [7:0] dist_10, dist_11, dist_12, dist_13,
    input [7:0] dist_20, dist_21, dist_22, dist_23,
    input [7:0] dist_30, dist_31, dist_32, dist_33,
    output reg possible,
    output reg done
);

// State definitions
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPARE = 2'd1;
localparam [1:0] DONE = 2'd2;

reg [1:0] state;
reg [2:0] perm_index;
reg found;
reg [7:0] max_perm;

// Distance matrix array
wire [7:0] dist [0:3][0:3];
assign dist[0][0] = dist_00; assign dist[0][1] = dist_01; assign dist[0][2] = dist_02; assign dist[0][3] = dist_03;
assign dist[1][0] = dist_10; assign dist[1][1] = dist_11; assign dist[1][2] = dist_12; assign dist[1][3] = dist_13;
assign dist[2][0] = dist_20; assign dist[2][1] = dist_21; assign dist[2][2] = dist_22; assign dist[2][3] = dist_23;
assign dist[3][0] = dist_30; assign dist[3][1] = dist_31; assign dist[3][2] = dist_32; assign dist[3][3] = dist_33;

// Combinational logic to compute total distance for current permutation
reg [15:0] total_sum;
always @(*) begin
    total_sum = 16'd0;
    case (n)
        3'd2: begin
            total_sum = {8'd0, dist[0][1]} + {8'd0, dist[1][0]};
        end
        3'd3: begin
            case (perm_index)
                3'd0: total_sum = {8'd0, dist[0][1]} + {8'd0, dist[1][2]} + {8'd0, dist[2][0]};
                3'd1: total_sum = {8'd0, dist[0][2]} + {8'd0, dist[2][1]} + {8'd0, dist[1][0]};
                default: total_sum = 16'd0;
            endcase
        end
        3'd4: begin
            case (perm_index)
                3'd0: total_sum = {8'd0, dist[0][1]} + {8'd0, dist[1][2]} + {8'd0, dist[2][3]} + {8'd0, dist[3][0]};
                3'd1: total_sum = {8'd0, dist[0][1]} + {8'd0, dist[1][3]} + {8'd0, dist[3][2]} + {8'd0, dist[2][0]};
                3'd2: total_sum = {8'd0, dist[0][2]} + {8'd0, dist[2][1]} + {8'd0, dist[1][3]} + {8'd0, dist[3][0]};
                3'd3: total_sum = {8'd0, dist[0][2]} + {8'd0, dist[2][3]} + {8'd0, dist[3][1]} + {8'd0, dist[1][0]};
                3'd4: total_sum = {8'd0, dist[0][3]} + {8'd0, dist[3][1]} + {8'd0, dist[1][2]} + {8'd0, dist[2][0]};
                3'd5: total_sum = {8'd0, dist[0][3]} + {8'd0, dist[3][2]} + {8'd0, dist[2][1]} + {8'd0, dist[1][0]};
                default: total_sum = 16'd0;
            endcase
        end
        default: total_sum = 16'd0;
    endcase
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        perm_index <= 3'd0;
        found <= 1'b0;
        done <= 1'b0;
        possible <= 1'b0;
        max_perm <= 8'd0;
    end else begin
        done <= 1'b0;
        case (state)
            IDLE: begin
                found <= 1'b0;
                perm_index <= 3'd0;
                if (start) begin
                    state <= COMPARE;
                    case (n)
                        3'd2: max_perm <= 8'd1;
                        3'd3: max_perm <= 8'd2;
                        3'd4: max_perm <= 8'd6;
                        default: max_perm <= 8'd0;
                    endcase
                end
            end
            COMPARE: begin
                // Check current permutation
                if (total_sum == {8'd0, L}) found <= 1'b1;
                // Move to next permutation or finish
                if (perm_index < max_perm - 8'd1) begin
                    perm_index <= perm_index + 3'd1;
                end else begin
                    state <= DONE;
                end
            end
            DONE: begin
                done <= 1'b1;
                possible <= found;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule