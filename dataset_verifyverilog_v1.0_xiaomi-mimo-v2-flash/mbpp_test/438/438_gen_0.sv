module bidirectional_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0_a,
    input wire [7:0] arr_0_b,
    input wire [7:0] arr_1_a,
    input wire [7:0] arr_1_b,
    input wire [7:0] arr_2_a,
    input wire [7:0] arr_2_b,
    input wire [7:0] arr_3_a,
    input wire [7:0] arr_3_b,
    input wire [7:0] arr_4_a,
    input wire [7:0] arr_4_b,
    input wire [7:0] arr_5_a,
    input wire [7:0] arr_5_b,
    input wire [7:0] arr_6_a,
    input wire [7:0] arr_6_b,
    input wire [7:0] arr_7_a,
    input wire [7:0] arr_7_b,
    input wire [3:0] num_tuples,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD        = 3'd1;
    localparam [2:0] OUTER_LOOP  = 3'd2;
    localparam [2:0] INNER_LOOP  = 3'd3;
    localparam [2:0] COMPARE     = 3'd4;
    localparam [2:0] INCREMENT   = 3'd5;
    localparam [2:0] DONE_STATE  = 3'd6;

    // Register storage for tuples
    reg [7:0] tuple_a[0:7];
    reg [7:0] tuple_b[0:7];
    
    // Control registers
    reg [2:0] state;
    reg [2:0] j_index;  // Outer loop index (0 to num_tuples-2)
    reg [2:0] i_index;  // Inner loop index (j+1 to num_tuples-1)
    reg [3:0] cycle_counter;  // To prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd30;
    
    // Combinational comparison results
    wire comp_a_match;
    wire comp_b_match;
    wire pair_match;
    
    assign comp_a_match = (tuple_a[j_index] == tuple_a[i_index]);
    assign comp_b_match = (tuple_b[j_index] == tuple_b[i_index]);
    assign pair_match = comp_a_match && comp_b_match;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            j_index <= 3'd0;
            i_index <= 3'd0;
            cycle_counter <= 4'd0;
            // Initialize tuple storage
            tuple_a[0] <= 8'd0; tuple_b[0] <= 8'd0;
            tuple_a[1] <= 8'd0; tuple_b[1] <= 8'd0;
            tuple_a[2] <= 8'd0; tuple_b[2] <= 8'd0;
            tuple_a[3] <= 8'd0; tuple_b[3] <= 8'd0;
            tuple_a[4] <= 8'd0; tuple_b[4] <= 8'd0;
            tuple_a[5] <= 8'd0; tuple_b[5] <= 8'd0;
            tuple_a[6] <= 8'd0; tuple_b[6] <= 8'd0;
            tuple_a[7] <= 8'd0; tuple_b[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    cycle_counter <= 4'd0;
                    j_index <= 3'd0;
                    i_index <= 3'd0;
                    if (start) begin
                        if (num_tuples < 2) begin
                            // Fast path: no pairs possible
                            state <= DONE_STATE;
                        end else begin
                            state <= LOAD;
                        end
                    end
                end
                
                LOAD: begin
                    // Load all 8 tuples (some may be unused)
                    tuple_a[0] <= arr_0_a; tuple_b[0] <= arr_0_b;
                    tuple_a[1] <= arr_1_a; tuple_b[1] <= arr_1_b;
                    tuple_a[2] <= arr_2_a; tuple_b[2] <= arr_2_b;
                    tuple_a[3] <= arr_3_a; tuple_b[3] <= arr_3_b;
                    tuple_a[4] <= arr_4_a; tuple_b[4] <= arr_4_b;
                    tuple_a[5] <= arr_5_a; tuple_b[5] <= arr_5_b;
                    tuple_a[6] <= arr_6_a; tuple_b[6] <= arr_6_b;
                    tuple_a[7] <= arr_7_a; tuple_b[7] <= arr_7_b;
                    j_index <= 3'd0;
                    i_index <= 3'd1;
                    state <= OUTER_LOOP;
                end
                
                OUTER_LOOP: begin
                    // Check if outer loop should continue
                    if (j_index < num_tuples - 2) begin
                        // Reset inner loop index
                        i_index <= j_index + 3'd1;
                        state <= INNER_LOOP;
                    end else begin
                        // All pairs processed
                        state <= DONE_STATE;
                    end
                end
                
                INNER_LOOP: begin
                    // Check if inner loop should continue
                    if (i_index < num_tuples) begin
                        // Check next pair
                        state <= COMPARE;
                    end else begin
                        // Inner loop done, increment outer loop
                        state <= OUTER_LOOP;
                        j_index <= j_index + 3'd1;
                    end
                end
                
                COMPARE: begin
                    // Compare tuples[j] and tuple[i]
                    if (pair_match) begin
                        state <= INCREMENT;
                    end else begin
                        // No match, continue inner loop
                        state <= INNER_LOOP;
                        i_index <= i_index + 3'd1;
                    end
                end
                
                INCREMENT: begin
                    // Found a bidirectional pair
                    result <= result + 16'd1;
                    state <= INNER_LOOP;
                    i_index <= i_index + 3'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Safety: increment cycle counter, timeout after MAX_CYCLES
            if (state != IDLE && state != DONE_STATE) begin
                cycle_counter <= cycle_counter + 4'd1;
                if (cycle_counter >= MAX_CYCLES) begin
                    state <= DONE_STATE;
                end
            end
        end
    end

endmodule