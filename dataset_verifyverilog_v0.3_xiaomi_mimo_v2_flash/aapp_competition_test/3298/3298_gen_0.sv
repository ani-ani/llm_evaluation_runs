module unsorted_checker(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg done,
    output reg is_unsorted
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Computation registers
    reg [2:0] k;  // Current element index (0-7)
    reg [2:0] j;  // Comparison index
    reg all_unsorted;  // Track if any element is sorted
    reg element_sorted;  // Temporary flag for current element
    reg all_greater;  // Check if all left elements are <= current
    reg all_less;     // Check if all right elements are >= current
    reg [7:0] current_arr;  // Current element being checked
    
    // Combinational array access
    wire [7:0] arr [0:7];
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            is_unsorted <= 1'b0;
            k <= 3'd0;
            j <= 3'd0;
            all_unsorted <= 1'b1;
            element_sorted <= 1'b0;
            all_greater <= 1'b0;
            all_less <= 1'b0;
            current_arr <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    is_unsorted <= 1'b0;
                    k <= 3'd0;
                    j <= 3'd0;
                    all_unsorted <= 1'b1;
                    element_sorted <= 1'b0;
                    all_greater <= 1'b0;
                    all_less <= 1'b0;
                    current_arr <= 8'd0;
                end
                
                COMPUTE: begin
                    // State machine for checking elements
                    case ({k < len[2:0], j < len[2:0]})
                        2'b00: begin  // Finished checking element k
                            // Check if current element is sorted
                            if (all_greater && all_less) begin
                                element_sorted <= 1'b1;
                                all_unsorted <= 1'b0;
                            end else begin
                                element_sorted <= 1'b0;
                            end
                            j <= 3'd0;  // Reset for next element
                        end
                        2'b01: begin  // Check left side (j < k)
                            if (j < k) begin
                                if (arr[j] > current_arr) begin
                                    all_greater <= 1'b0;
                                end else if (j == 3'd0 && k > 3'd0) begin
                                    all_greater <= 1'b1;
                                end
                            end
                            j <= j + 3'd1;
                        end
                        2'b10: begin  // Check right side (j > k)
                            // This case shouldn't happen in our logic
                            j <= j + 3'd1;
                        end
                        2'b11: begin  // Check both sides
                            // Left side check (j < k)
                            if (j < k) begin
                                if (arr[j] > current_arr) begin
                                    all_greater <= 1'b0;
                                end else if (j == 3'd0 && k > 3'd0) begin
                                    all_greater <= 1'b1;
                                end
                            end
                            // Right side check (j > k)
                            else if (j > k) begin
                                if (arr[j] < current_arr) begin
                                    all_less <= 1'b0;
                                end else if (j == 3'd1 && k == 3'd0) begin
                                    all_less <= 1'b1;
                                end
                            end
                            // Reset for next element when done checking all j
                            else if (j == len[2:0] - 3'd1 && k < len[2:0]) begin
                                if (all_greater && all_less) begin
                                    element_sorted <= 1'b1;
                                    all_unsorted <= 1'b0;
                                end else begin
                                    element_sorted <= 1'b0;
                                end
                                j <= 3'd0;
                            end
                            j <= j + 3'd1;
                        end
                        default: begin
                            j <= j + 3'd1;
                        end
                    endcase
                    
                    // Reset flags when starting new element
                    if (j == 3'd0 && k < len[2:0]) begin
                        all_greater <= 1'b1;
                        all_less <= 1'b1;
                        current_arr <= arr[k];
                        k <= k + 3'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    is_unsorted <= all_unsorted;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    is_unsorted <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Transition to FINISH when all elements checked
                if (k >= len[2:0] && j >= len[2:0]) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule