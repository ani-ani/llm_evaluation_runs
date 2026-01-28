module closest_pair_finder(
    input clk,
    input rst_n,
    input start,
    input [15:0] data [0:15],
    input [15:0] valid_mask,
    output reg [15:0] result_a,
    output reg [15:0] result_b,
    output reg result_valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT  = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i_reg, j_reg;
    reg [15:0] min_diff;
    reg [15:0] current_diff;
    reg [15:0] best_a, best_b;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd120;

    // Absolute difference calculation
    wire [15:0] abs_diff;
    assign abs_diff = (data[i_reg] > data[j_reg]) ? (data[i_reg] - data[j_reg]) : (data[j_reg] - data[i_reg]);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            min_diff <= 16'd0;
            current_diff <= 16'd0;
            best_a <= 16'd0;
            best_b <= 16'd0;
            result_a <= 16'd0;
            result_b <= 16'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Initialize computation registers
                    i_reg <= 4'd0;
                    j_reg <= 4'd1;
                    min_diff <= 16'd32767; // Initialize to max possible difference
                    best_a <= 16'd0;
                    best_b <= 16'd0;
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current pair is valid
                    if (valid_mask[i_reg] && valid_mask[j_reg]) begin
                        current_diff <= abs_diff;
                        
                        // Update best pair if current difference is smaller
                        if (current_diff < min_diff) begin
                            min_diff <= current_diff;
                            best_a <= (data[i_reg] < data[j_reg]) ? data[i_reg] : data[j_reg];
                            best_b <= (data[i_reg] > data[j_reg]) ? data[i_reg] : data[j_reg];
                        end
                    end
                    
                    // Move to next pair
                    j_reg <= j_reg + 4'd1;
                    
                    // Check if we've processed all pairs for current i
                    if (j_reg == 4'd16) begin
                        i_reg <= i_reg + 4'd1;
                        j_reg <= i_reg + 4'd1;
                    end
                    
                    // Check if all pairs processed or max cycles reached
                    if ((i_reg == 4'd15 && j_reg == 4'd16) || cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                OUTPUT: begin
                    // Check if we found at least one valid pair
                    if (min_diff < 16'd32767) begin
                        result_a <= best_a;
                        result_b <= best_b;
                        result_valid <= 1'b1;
                    end else begin
                        result_a <= 16'd0;
                        result_b <= 16'd0;
                        result_valid <= 1'b0;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule