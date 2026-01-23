module median_finder (
    input clk,
    input rst_n,
    input start,
    input [15:0] data_in,
    input valid_in,
    input [2:0] index,
    input [3:0] count,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOADING  = 3'd1;
    localparam [2:0] SORTING  = 3'd2;
    localparam [2:0] COMPUTING = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] array_reg [0:7];  // Internal array storage
    reg [2:0] load_idx;
    reg [2:0] load_count;
    reg [2:0] sort_pass;
    reg [2:0] sort_idx;
    reg [2:0] compute_step;
    reg [31:0] temp_sum;
    reg [2:0] i;  // Loop variable for array initialization

    // Control signals
    reg array_loaded;
    reg sort_complete;
    reg compute_done;

    // Initialize array to zero on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                array_reg[i] <= 16'd0;
            end
        end
    end

    // State machine next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && valid_in) begin
                    next_state = LOADING;
                end else begin
                    next_state = IDLE;
                end
            end

            LOADING: begin
                if (array_loaded) begin
                    next_state = SORTING;
                end else begin
                    next_state = LOADING;
                end
            end

            SORTING: begin
                if (sort_complete) begin
                    next_state = COMPUTING;
                end else begin
                    next_state = SORTING;
                end
            end

            COMPUTING: begin
                if (compute_done) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPUTING;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // State machine sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            load_idx <= 3'd0;
            load_count <= 3'd0;
            sort_pass <= 3'd0;
            sort_idx <= 3'd0;
            compute_step <= 3'd0;
            temp_sum <= 32'd0;
            array_loaded <= 1'b0;
            sort_complete <= 1'b0;
            compute_done <= 1'b0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    load_count <= 3'd0;
                    load_idx <= 3'd0;
                    sort_pass <= 3'd0;
                    sort_idx <= 3'd0;
                    compute_step <= 3'd0;
                    temp_sum <= 32'd0;
                    array_loaded <= 1'b0;
                    sort_complete <= 1'b0;
                    compute_done <= 1'b0;
                end

                LOADING: begin
                    if (valid_in && load_count < count[2:0]) begin
                        array_reg[index] <= data_in;
                        load_count <= load_count + 3'd1;
                    end
                    if (load_count >= count[2:0] && count > 4'd0) begin
                        array_loaded <= 1'b1;
                    end
                end

                SORTING: begin
                    // Bubble sort network (max 8 passes)
                    if (sort_pass < 3'd8) begin
                        if (sort_idx < count[2:0] - 3'd1) begin
                            // Compare and swap adjacent elements
                            if (array_reg[sort_idx] > array_reg[sort_idx + 3'd1]) begin
                                array_reg[sort_idx] <= array_reg[sort_idx + 3'd1];
                                array_reg[sort_idx + 3'd1] <= array_reg[sort_idx];
                            end
                            sort_idx <= sort_idx + 3'd1;
                        end else begin
                            sort_idx <= 3'd0;
                            sort_pass <= sort_pass + 3'd1;
                        end
                    end else begin
                        sort_complete <= 1'b1;
                    end
                end

                COMPUTING: begin
                    if (compute_step == 3'd0) begin
                        // First compute step
                        if (count[0]) begin
                            // Odd count: result = array[count/2]
                            result <= {16'd0, array_reg[count[2:1]]};  // Shift left 16 for Q16.16
                            compute_done <= 1'b1;
                        end else begin
                            // Even count: compute sum of two middle elements
                            temp_sum <= {16'd0, array_reg[count[2:1] - 3'd1]} + {16'd0, array_reg[count[2:1]]};
                            compute_step <= 3'd1;
                        end
                    end else if (compute_step == 3'd1) begin
                        // Second step for even count (divide by 2)
                        result <= temp_sum >> 1;  // Logical right shift
                        compute_done <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= result;  // Hold result
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule