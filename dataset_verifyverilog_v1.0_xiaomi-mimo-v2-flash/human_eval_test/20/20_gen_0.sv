module closest_pair (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] data [0:15],
    input wire [15:0] valid_mask,
    output reg [15:0] result_a,
    output reg [15:0] result_b,
    output reg result_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [15:0] saved_data [0:15];
    reg [15:0] saved_valid_mask;
    reg [15:0] current_a, current_b, current_diff;
    reg [15:0] best_a, best_b, best_diff;
    reg [3:0] i_count, j_count;
    reg [4:0] cycle_count;
    reg [4:0] valid_count;
    reg found_first_valid;
    
    // Combinational signals
    wire [15:0] diff_val;
    wire [15:0] abs_diff;
    wire a_valid, b_valid, pair_valid;
    
    // Determine which elements to compare
    assign a_valid = saved_valid_mask[i_count];
    assign b_valid = saved_valid_mask[j_count];
    assign pair_valid = a_valid && b_valid && (i_count != j_count);
    
    // Calculate difference
    wire signed [15:0] signed_a;
    wire signed [15:0] signed_b;
    wire signed [16:0] signed_diff;
    
    assign signed_a = saved_data[i_count];
    assign signed_b = saved_data[j_count];
    assign signed_diff = signed_a - signed_b;
    
    // Absolute value
    assign abs_diff = (signed_diff[15]) ? (~signed_diff + 16'd1) : signed_diff[15:0];
    
    // Count valid elements
    integer v_idx;
    always @(*) begin
        valid_count = 5'd0;
        for (v_idx = 0; v_idx < 16; v_idx = v_idx + 1) begin
            if (valid_mask[v_idx]) begin
                valid_count = valid_count + 5'd1;
            end
        end
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_a <= 16'd0;
            result_b <= 16'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            best_a <= 16'd0;
            best_b <= 16'd0;
            best_diff <= 16'hFFFF;
            i_count <= 4'd0;
            j_count <= 4'd0;
            cycle_count <= 5'd0;
            found_first_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Load data into internal registers
                    for (int idx = 0; idx < 16; idx = idx + 1) begin
                        saved_data[idx] <= data[idx];
                    end
                    saved_valid_mask <= valid_mask;
                    best_diff <= 16'hFFFF;
                    i_count <= 4'd0;
                    j_count <= 4'd1;
                    cycle_count <= 5'd0;
                    found_first_valid <= 1'b0;
                    
                    // Check if there are at least 2 valid elements
                    if (valid_count >= 5'd2) begin
                        state <= COMPUTE;
                    end else begin
                        // Less than 2 valid elements, go directly to output
                        state <= FINISH;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Compare current pair
                    if (pair_valid) begin
                        if (!found_first_valid || abs_diff < best_diff) begin
                            best_diff <= abs_diff;
                            // Ensure smaller element is stored in result_a
                            if (saved_data[i_count] < saved_data[j_count]) begin
                                best_a <= saved_data[i_count];
                                best_b <= saved_data[j_count];
                            end else begin
                                best_a <= saved_data[j_count];
                                best_b <= saved_data[i_count];
                            end
                            found_first_valid <= 1'b1;
                        end
                    end
                    
                    // Increment counters for pair traversal
                    if (j_count < 4'd15) begin
                        j_count <= j_count + 4'd1;
                    end else begin
                        j_count <= i_count + 4'd2;
                        i_count <= i_count + 4'd1;
                    end
                    
                    // Check completion: i goes from 0 to 14, j from i+1 to 15
                    // Total pairs = 15 + 14 + ... + 1 = 120
                    if (i_count == 4'd14 && j_count == 4'd15) begin
                        state <= OUTPUT;
                    end
                    
                    // Safety: prevent infinite loops (should not happen)
                    if (cycle_count >= 5'd20) begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    result_a <= best_a;
                    result_b <= best_b;
                    result_valid <= found_first_valid;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule