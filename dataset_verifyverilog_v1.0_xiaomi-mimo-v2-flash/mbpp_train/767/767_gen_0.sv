module pair_count (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr_in_0,
    input wire signed [7:0] arr_in_1,
    input wire signed [7:0] arr_in_2,
    input wire signed [7:0] arr_in_3,
    input wire signed [7:0] arr_in_4,
    input wire signed [7:0] arr_in_5,
    input wire signed [7:0] arr_in_6,
    input wire signed [7:0] arr_in_7,
    input wire signed [7:0] arr_in_8,
    input wire signed [7:0] arr_in_9,
    input wire signed [7:0] arr_in_10,
    input wire signed [7:0] arr_in_11,
    input wire signed [7:0] arr_in_12,
    input wire signed [7:0] arr_in_13,
    input wire signed [7:0] arr_in_14,
    input wire signed [7:0] arr_in_15,
    input wire [3:0] len,
    input wire signed [7:0] target_sum,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg signed [7:0] arr_reg [0:15];  // Array storage
    reg [3:0] i;  // Outer loop index
    reg [3:0] j;  // Inner loop index
    reg [7:0] counter;  // Pair counter (unsigned)
    reg [7:0] temp_result;
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;  // Safe upper bound

    // Temporary signals for computation
    wire signed [8:0] sum_temp;  // 9-bit signed for overflow detection
    wire [7:0] sum_trunc;
    wire match;

    assign sum_temp = arr_reg[i] + arr_reg[j];
    assign sum_trunc = sum_temp[7:0];  // Truncate to 8-bit
    assign match = (sum_trunc == target_sum);

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            counter <= 8'd0;
            temp_result <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize array storage
            arr_reg[0] <= 8'sd0;
            arr_reg[1] <= 8'sd0;
            arr_reg[2] <= 8'sd0;
            arr_reg[3] <= 8'sd0;
            arr_reg[4] <= 8'sd0;
            arr_reg[5] <= 8'sd0;
            arr_reg[6] <= 8'sd0;
            arr_reg[7] <= 8'sd0;
            arr_reg[8] <= 8'sd0;
            arr_reg[9] <= 8'sd0;
            arr_reg[10] <= 8'sd0;
            arr_reg[11] <= 8'sd0;
            arr_reg[12] <= 8'sd0;
            arr_reg[13] <= 8'sd0;
            arr_reg[14] <= 8'sd0;
            arr_reg[15] <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 8'd0;
                    temp_result <= 8'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load input array into internal storage
                    arr_reg[0] <= arr_in_0;
                    arr_reg[1] <= arr_in_1;
                    arr_reg[2] <= arr_in_2;
                    arr_reg[3] <= arr_in_3;
                    arr_reg[4] <= arr_in_4;
                    arr_reg[5] <= arr_in_5;
                    arr_reg[6] <= arr_in_6;
                    arr_reg[7] <= arr_in_7;
                    arr_reg[8] <= arr_in_8;
                    arr_reg[9] <= arr_in_9;
                    arr_reg[10] <= arr_in_10;
                    arr_reg[11] <= arr_in_11;
                    arr_reg[12] <= arr_in_12;
                    arr_reg[13] <= arr_in_13;
                    arr_reg[14] <= arr_in_14;
                    arr_reg[15] <= arr_in_15;
                    
                    // Initialize loop indices
                    i <= 4'd0;
                    j <= 4'd1;
                    
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if pair indices are valid for current length
                    if ((i < len - 4'd1) && (j < len) && (j > i)) begin
                        // Check pair sum match
                        if (match) begin
                            if (counter < 8'd255) begin
                                counter <= counter + 8'd1;
                            end
                        end
                        
                        // Increment inner index
                        j <= j + 4'd1;
                    end else begin
                        // Move to next outer index
                        j <= i + 4'd2;
                        i <= i + 4'd1;
                    end
                    
                    // Exit conditions
                    if ((i >= len - 4'd1) || (cycle_count >= MAX_CYCLES)) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= counter;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule