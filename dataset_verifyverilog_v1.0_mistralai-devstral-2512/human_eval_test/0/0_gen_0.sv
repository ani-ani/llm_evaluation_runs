module has_close_elements(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] data_in,
    input wire [2:0] addr_in,
    input wire we,
    input wire [15:0] threshold,
    output reg result,
    output reg done
);

    // Internal array storage
    reg [15:0] array [0:7];
    
    // State machine declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    
    reg [2:0] state, next_state;
    reg [15:0] latched_threshold;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;
    
    // Array write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            next_state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            latched_threshold <= 16'd0;
            
            // Initialize array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                array[i] <= 16'd0;
            end
        end else begin
            // Write to array when we is high
            if (we) begin
                array[addr_in] <= data_in;
            end
            
            // State machine
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        latched_threshold <= threshold;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Compute all pairs in parallel
                    reg [16:0] diff_01, diff_02, diff_03, diff_04, diff_05, diff_06, diff_07;
                    reg [16:0] diff_12, diff_13, diff_14, diff_15, diff_16, diff_17;
                    reg [16:0] diff_23, diff_24, diff_25, diff_26, diff_27;
                    reg [16:0] diff_34, diff_35, diff_36, diff_37;
                    reg [16:0] diff_45, diff_46, diff_47;
                    reg [16:0] diff_56, diff_57;
                    reg [16:0] diff_67;
                    
                    // Compute absolute differences
                    // Pair 0-1
                    if (array[0] > array[1]) begin
                        diff_01 = array[0] - array[1];
                    end else begin
                        diff_01 = array[1] - array[0];
                    end
                    
                    // Pair 0-2
                    if (array[0] > array[2]) begin
                        diff_02 = array[0] - array[2];
                    end else begin
                        diff_02 = array[2] - array[0];
                    end
                    
                    // Pair 0-3
                    if (array[0] > array[3]) begin
                        diff_03 = array[0] - array[3];
                    end else begin
                        diff_03 = array[3] - array[0];
                    end
                    
                    // Pair 0-4
                    if (array[0] > array[4]) begin
                        diff_04 = array[0] - array[4];
                    end else begin
                        diff_04 = array[4] - array[0];
                    end
                    
                    // Pair 0-5
                    if (array[0] > array[5]) begin
                        diff_05 = array[0] - array[5];
                    end else begin
                        diff_05 = array[5] - array[0];
                    end
                    
                    // Pair 0-6
                    if (array[0] > array[6]) begin
                        diff_06 = array[0] - array[6];
                    end else begin
                        diff_06 = array[6] - array[0];
                    end
                    
                    // Pair 0-7
                    if (array[0] > array[7]) begin
                        diff_07 = array[0] - array[7];
                    end else begin
                        diff_07 = array[7] - array[0];
                    end
                    
                    // Pair 1-2
                    if (array[1] > array[2]) begin
                        diff_12 = array[1] - array[2];
                    end else begin
                        diff_12 = array[2] - array[1];
                    end
                    
                    // Pair 1-3
                    if (array[1] > array[3]) begin
                        diff_13 = array[1] - array[3];
                    end else begin
                        diff_13 = array[3] - array[1];
                    end
                    
                    // Pair 1-4
                    if (array[1] > array[4]) begin
                        diff_14 = array[1] - array[4];
                    end else begin
                        diff_14 = array[4] - array[1];
                    end
                    
                    // Pair 1-5
                    if (array[1] > array[5]) begin
                        diff_15 = array[1] - array[5];
                    end else begin
                        diff_15 = array[5] - array[1];
                    end
                    
                    // Pair 1-6
                    if (array[1] > array[6]) begin
                        diff_16 = array[1] - array[6];
                    end else begin
                        diff_16 = array[6] - array[1];
                    end
                    
                    // Pair 1-7
                    if (array[1] > array[7]) begin
                        diff_17 = array[1] - array[7];
                    end else begin
                        diff_17 = array[7] - array[1];
                    end
                    
                    // Pair 2-3
                    if (array[2] > array[3]) begin
                        diff_23 = array[2] - array[3];
                    end else begin
                        diff_23 = array[3] - array[2];
                    end
                    
                    // Pair 2-4
                    if (array[2] > array[4]) begin
                        diff_24 = array[2] - array[4];
                    end else begin
                        diff_24 = array[4] - array[2];
                    end
                    
                    // Pair 2-5
                    if (array[2] > array[5]) begin
                        diff_25 = array[2] - array[5];
                    end else begin
                        diff_25 = array[5] - array[2];
                    end
                    
                    // Pair 2-6
                    if (array[2] > array[6]) begin
                        diff_26 = array[2] - array[6];
                    end else begin
                        diff_26 = array[6] - array[2];
                    end
                    
                    // Pair 2-7
                    if (array[2] > array[7]) begin
                        diff_27 = array[2] - array[7];
                    end else begin
                        diff_27 = array[7] - array[2];
                    end
                    
                    // Pair 3-4
                    if (array[3] > array[4]) begin
                        diff_34 = array[3] - array[4];
                    end else begin
                        diff_34 = array[4] - array[3];
                    end
                    
                    // Pair 3-5
                    if (array[3] > array[5]) begin
                        diff_35 = array[3] - array[5];
                    end else begin
                        diff_35 = array[5] - array[3];
                    end
                    
                    // Pair 3-6
                    if (array[3] > array[6]) begin
                        diff_36 = array[3] - array[6];
                    end else begin
                        diff_36 = array[6] - array[3];
                    end
                    
                    // Pair 3-7
                    if (array[3] > array[7]) begin
                        diff_37 = array[3] - array[7];
                    end else begin
                        diff_37 = array[7] - array[3];
                    end
                    
                    // Pair 4-5
                    if (array[4] > array[5]) begin
                        diff_45 = array[4] - array[5];
                    end else begin
                        diff_45 = array[5] - array[4];
                    end
                    
                    // Pair 4-6
                    if (array[4] > array[6]) begin
                        diff_46 = array[4] - array[6];
                    end else begin
                        diff_46 = array[6] - array[4];
                    end
                    
                    // Pair 4-7
                    if (array[4] > array[7]) begin
                        diff_47 = array[4] - array[7];
                    end else begin
                        diff_47 = array[7] - array[4];
                    end
                    
                    // Pair 5-6
                    if (array[5] > array[6]) begin
                        diff_56 = array[5] - array[6];
                    end else begin
                        diff_56 = array[6] - array[5];
                    end
                    
                    // Pair 5-7
                    if (array[5] > array[7]) begin
                        diff_57 = array[5] - array[7];
                    end else begin
                        diff_57 = array[7] - array[5];
                    end
                    
                    // Pair 6-7
                    if (array[6] > array[7]) begin
                        diff_67 = array[6] - array[7];
                    end else begin
                        diff_67 = array[7] - array[6];
                    end
                    
                    // Check if any difference is less than threshold
                    result <= (diff_01 < latched_threshold) ||
                             (diff_02 < latched_threshold) ||
                             (diff_03 < latched_threshold) ||
                             (diff_04 < latched_threshold) ||
                             (diff_05 < latched_threshold) ||
                             (diff_06 < latched_threshold) ||
                             (diff_07 < latched_threshold) ||
                             (diff_12 < latched_threshold) ||
                             (diff_13 < latched_threshold) ||
                             (diff_14 < latched_threshold) ||
                             (diff_15 < latched_threshold) ||
                             (diff_16 < latched_threshold) ||
                             (diff_17 < latched_threshold) ||
                             (diff_23 < latched_threshold) ||
                             (diff_24 < latched_threshold) ||
                             (diff_25 < latched_threshold) ||
                             (diff_26 < latched_threshold) ||
                             (diff_27 < latched_threshold) ||
                             (diff_34 < latched_threshold) ||
                             (diff_35 < latched_threshold) ||
                             (diff_36 < latched_threshold) ||
                             (diff_37 < latched_threshold) ||
                             (diff_45 < latched_threshold) ||
                             (diff_46 < latched_threshold) ||
                             (diff_47 < latched_threshold) ||
                             (diff_56 < latched_threshold) ||
                             (diff_57 < latched_threshold) ||
                             (diff_67 < latched_threshold);
                    
                    // Transition to output state
                    if (cycle_count >= MAX_CYCLES - 1) begin
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end
endmodule