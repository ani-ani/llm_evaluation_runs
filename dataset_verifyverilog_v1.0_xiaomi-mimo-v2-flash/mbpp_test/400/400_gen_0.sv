module unique_tuples (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuple_arr [0:15] [0:1],
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT_TUPLES = 3'd1;
    localparam [2:0] COMPARE_TUPLES = 3'd2;
    localparam [2:0] INCREMENT_COUNT = 3'd3;
    localparam [2:0] CHECK_DUPLICATE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers for state machine
    reg [2:0] state, next_state;
    reg [3:0] i; // Outer loop index (current tuple being checked)
    reg [3:0] j; // Inner loop index (comparing with previous tuples)
    reg [7:0] sorted_tuples [0:15] [0:1]; // Storage for sorted tuples
    reg duplicate_found; // Flag for duplicate detection
    reg [7:0] temp_count; // Temporary count

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            duplicate_found <= 1'b0;
            temp_count <= 8'd0;
            // Initialize sorted_tuples array
            sorted_tuples[0][0] <= 8'd0; sorted_tuples[0][1] <= 8'd0;
            sorted_tuples[1][0] <= 8'd0; sorted_tuples[1][1] <= 8'd0;
            sorted_tuples[2][0] <= 8'd0; sorted_tuples[2][1] <= 8'd0;
            sorted_tuples[3][0] <= 8'd0; sorted_tuples[3][1] <= 8'd0;
            sorted_tuples[4][0] <= 8'd0; sorted_tuples[4][1] <= 8'd0;
            sorted_tuples[5][0] <= 8'd0; sorted_tuples[5][1] <= 8'd0;
            sorted_tuples[6][0] <= 8'd0; sorted_tuples[6][1] <= 8'd0;
            sorted_tuples[7][0] <= 8'd0; sorted_tuples[7][1] <= 8'd0;
            sorted_tuples[8][0] <= 8'd0; sorted_tuples[8][1] <= 8'd0;
            sorted_tuples[9][0] <= 8'd0; sorted_tuples[9][1] <= 8'd0;
            sorted_tuples[10][0] <= 8'd0; sorted_tuples[10][1] <= 8'd0;
            sorted_tuples[11][0] <= 8'd0; sorted_tuples[11][1] <= 8'd0;
            sorted_tuples[12][0] <= 8'd0; sorted_tuples[12][1] <= 8'd0;
            sorted_tuples[13][0] <= 8'd0; sorted_tuples[13][1] <= 8'd0;
            sorted_tuples[14][0] <= 8'd0; sorted_tuples[14][1] <= 8'd0;
            sorted_tuples[15][0] <= 8'd0; sorted_tuples[15][1] <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    temp_count <= 8'd0;
                    duplicate_found <= 1'b0;
                    if (start) begin
                        // Pre-sort all tuples in parallel (combinational logic below)
                        // State transition will happen in next cycle
                    end
                end
                SORT_TUPLES: begin
                    // Sorting is done combinatorially before this state
                    // Just move to comparison phase
                    i <= 4'd1; // Start comparing from second tuple (index 1)
                    temp_count <= 8'd1; // First tuple is always unique
                    j <= 4'd0;
                    duplicate_found <= 1'b0;
                end
                COMPARE_TUPLES: begin
                    if (i < len) begin
                        j <= 4'd0;
                        duplicate_found <= 1'b0;
                    end else begin
                        // Done comparing all tuples
                        temp_count <= temp_count; // Keep final count
                    end
                end
                CHECK_DUPLICATE: begin
                    // Compare current tuple with previous tuple at index j
                    if (j < i) begin
                        if ((sorted_tuples[i][0] == sorted_tuples[j][0]) && 
                            (sorted_tuples[i][1] == sorted_tuples[j][1])) begin
                            duplicate_found <= 1'b1;
                        end else begin
                            duplicate_found <= duplicate_found;
                        end
                    end
                end
                INCREMENT_COUNT: begin
                    if (!duplicate_found) begin
                        temp_count <= temp_count + 8'd1;
                    end
                    duplicate_found <= 1'b0;
                    i <= i + 4'd1;
                end
                DONE_STATE: begin
                    result <= temp_count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                    result <= 8'd0;
                    done <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    temp_count <= 8'd0;
                    duplicate_found <= 1'b0;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (len > 4'd0)
                        next_state = SORT_TUPLES;
                    else
                        next_state = DONE_STATE; // Empty list, result=0
                end
            end
            SORT_TUPLES: begin
                next_state = COMPARE_TUPLES;
            end
            COMPARE_TUPLES: begin
                if (i < len)
                    next_state = CHECK_DUPLICATE;
                else
                    next_state = DONE_STATE;
            end
            CHECK_DUPLICATE: begin
                if (j < i)
                    next_state = CHECK_DUPLICATE;
                else
                    next_state = INCREMENT_COUNT;
            end
            INCREMENT_COUNT: begin
                next_state = COMPARE_TUPLES;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Combinational loop control logic (next j)
    always @(*) begin
        if (state == CHECK_DUPLICATE) begin
            if (j < i)
                j = j + 4'd1;
            else
                j = 4'd0;
        end else if (state == COMPARE_TUPLES) begin
            j = 4'd0;
        end else if (state == INCREMENT_COUNT) begin
            j = 4'd0;
        end else begin
            j = 4'd0;
        end
    end

    // Combinational sorting logic (parallel for all tuples)
    // For each tuple, sort the two elements (0,1) in ascending order
    always @(*) begin
        integer k;
        for (k = 0; k < 16; k = k + 1) begin
            if (tuple_arr[k][0] <= tuple_arr[k][1]) begin
                sorted_tuples[k][0] = tuple_arr[k][0];
                sorted_tuples[k][1] = tuple_arr[k][1];
            end else begin
                sorted_tuples[k][0] = tuple_arr[k][1];
                sorted_tuples[k][1] = tuple_arr[k][0];
            end
        end
    end

endmodule