module bitonic_subsequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_MSIBS = 3'd1;
    localparam [2:0] COMPUTE_MSDBS = 3'd2;
    localparam [2:0] COMPUTE_RESULT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // State register
    reg [2:0] state, next_state;

    // Memory arrays
    reg signed [15:0] MSIBS [0:15];
    reg signed [15:0] MSDBS [0:15];

    // Counters
    reg [3:0] i_counter;
    reg [3:0] j_counter;
    reg [3:0] max_i;

    // Temporary registers
    reg signed [15:0] temp_sum;
    reg signed [15:0] max_result;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            max_i <= 4'd0;
            max_result <= 16'd0;

            // Initialize arrays
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                MSIBS[k] <= 16'd0;
                MSDBS[k] <= 16'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE_MSIBS;
                        i_counter <= 4'd0;
                        // Initialize MSIBS with array values
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (k < len)
                                MSIBS[k] <= {8'd0, arr[k]};
                            else
                                MSIBS[k] <= 16'd0;
                        end
                    end
                end

                COMPUTE_MSIBS: begin
                    if (i_counter < len) begin
                        j_counter <= 4'd0;
                        if (j_counter < i_counter) begin
                            // Compare arr[i] > arr[j]
                            if (arr[i_counter] > arr[j_counter]) begin
                                temp_sum <= MSIBS[j_counter] + {8'd0, arr[i_counter]};
                                if (temp_sum > MSIBS[i_counter]) begin
                                    MSIBS[i_counter] <= temp_sum;
                                end
                            end
                            j_counter <= j_counter + 4'd1;
                        end else begin
                            i_counter <= i_counter + 4'd1;
                        end
                    end else begin
                        next_state <= COMPUTE_MSDBS;
                        i_counter <= len - 4'd1;
                        // Initialize MSDBS with array values
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (k < len)
                                MSDBS[k] <= {8'd0, arr[k]};
                            else
                                MSDBS[k] <= 16'd0;
                        end
                    end
                end

                COMPUTE_MSDBS: begin
                    if (i_counter >= 0) begin
                        j_counter <= i_counter + 4'd1;
                        if (j_counter < len) begin
                            // Compare arr[i] > arr[j]
                            if (arr[i_counter] > arr[j_counter]) begin
                                temp_sum <= MSDBS[j_counter] + {8'd0, arr[i_counter]};
                                if (temp_sum > MSDBS[i_counter]) begin
                                    MSDBS[i_counter] <= temp_sum;
                                end
                            end
                            j_counter <= j_counter + 4'd1;
                        end else begin
                            i_counter <= i_counter - 4'd1;
                        end
                    end else begin
                        next_state <= COMPUTE_RESULT;
                        max_i <= 4'd0;
                        max_result <= 16'd0;
                    end
                end

                COMPUTE_RESULT: begin
                    if (max_i < len) begin
                        temp_sum <= MSIBS[max_i] + MSDBS[max_i] - {8'd0, arr[max_i]};
                        if (max_i == 4'd0 || temp_sum > max_result) begin
                            max_result <= temp_sum;
                        end
                        max_i <= max_i + 4'd1;
                    end else begin
                        next_state <= DONE_STATE;
                        result <= max_result;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule