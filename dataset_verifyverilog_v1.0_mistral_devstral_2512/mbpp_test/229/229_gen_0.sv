module array_rearrange(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:7],
    input [3:0] n,
    output reg signed [7:0] result [0:7],
    output reg done,
    output reg [2:0] valid
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PHASE1    = 3'd1;
    localparam [2:0] PHASE2    = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    reg [2:0] state, next_state;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd64;

    // Internal registers for processing
    reg signed [7:0] temp_arr [0:7];
    reg [3:0] i, j;
    reg [3:0] neg_count, pos_count;
    reg signed [7:0] temp;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 6'd0;
            done <= 1'b0;
            valid <= 3'd0;

            // Initialize result array
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                result[k] <= 8'd0;
            end

            // Initialize internal registers
            i <= 4'd0;
            j <= 4'd0;
            neg_count <= 4'd0;
            pos_count <= 4'd0;
            temp <= 8'd0;

            // Initialize temp_arr
            for (k = 0; k < 8; k = k + 1) begin
                temp_arr[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 6'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        // Copy input array to temp_arr
                        integer k;
                        for (k = 0; k < 8; k = k + 1) begin
                            temp_arr[k] <= arr[k];
                        end
                        next_state <= PHASE1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PHASE1: begin
                    // Bubble negatives to front
                    if (i < n - 1) begin
                        if (j < n - i - 1) begin
                            if (temp_arr[j] >= 0 && temp_arr[j + 1] < 0) begin
                                // Swap elements
                                temp <= temp_arr[j];
                                temp_arr[j] <= temp_arr[j + 1];
                                temp_arr[j + 1] <= temp;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        next_state <= PHASE2;
                    end
                end

                PHASE2: begin
                    // Count negatives and positives
                    if (i < n) begin
                        if (temp_arr[i] < 0) begin
                            neg_count <= neg_count + 1;
                        end else begin
                            pos_count <= pos_count + 1;
                        end
                        i <= i + 1;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    // Write result to output
                    integer k;
                    for (k = 0; k < 8; k = k + 1) begin
                        if (k < n) begin
                            result[k] <= temp_arr[k];
                        end else begin
                            result[k] <= 8'd0;
                        end
                    end
                    valid <= n[3:0];
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule