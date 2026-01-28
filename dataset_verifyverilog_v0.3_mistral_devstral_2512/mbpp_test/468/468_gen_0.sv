module max_product (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] OUTER_LOOP = 3'd2;
    localparam [2:0] INNER_LOOP = 3'd3;
    localparam [2:0] UPDATE_MPI = 3'd4;
    localparam [2:0] FIND_MAX = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [3:0] i, j;
    reg [31:0] current_prod;
    reg [31:0] mpis [0:7];
    reg [7:0] arr [0:7];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            i <= 4'd0;
            j <= 4'd0;
            current_prod <= 32'd0;
            cycle_count <= 8'd0;
            // Initialize mpis array
            mpis[0] <= 32'd0;
            mpis[1] <= 32'd0;
            mpis[2] <= 32'd0;
            mpis[3] <= 32'd0;
            mpis[4] <= 32'd0;
            mpis[5] <= 32'd0;
            mpis[6] <= 32'd0;
            mpis[7] <= 32'd0;
            // Initialize arr array
            arr[0] <= 8'd0;
            arr[1] <= 8'd0;
            arr[2] <= 8'd0;
            arr[3] <= 8'd0;
            arr[4] <= 8'd0;
            arr[5] <= 8'd0;
            arr[6] <= 8'd0;
            arr[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && len > 4'd0) begin
                        // Store input array
                        arr[0] <= arr_0;
                        arr[1] <= arr_1;
                        arr[2] <= arr_2;
                        arr[3] <= arr_3;
                        arr[4] <= arr_4;
                        arr[5] <= arr_5;
                        arr[6] <= arr_6;
                        arr[7] <= arr_7;
                        i <= 4'd0;
                        state <= INIT;
                    end
                end

                INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else if (i < len) begin
                        // Initialize mpis[i] = arr[i]
                        mpis[i] <= {24'b0, arr[i]};
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= OUTER_LOOP;
                    end
                end

                OUTER_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else if (i < len) begin
                        // Initialize current_prod and j
                        current_prod <= {24'b0, arr[i]};
                        j <= i + 4'd1;
                        state <= INNER_LOOP;
                    end else begin
                        // Done with all loops, find max
                        result <= 32'd0;
                        i <= 4'd0;
                        state <= FIND_MAX;
                    end
                end

                INNER_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else if (j < len) begin
                        // Check if increasing (arr[j-1] <= arr[j])
                        if (arr[j-1] <= arr[j]) begin
                            // Update current_prod
                            current_prod <= current_prod * {24'b0, arr[j]};
                            state <= UPDATE_MPI;
                        end else begin
                            // Not increasing, break inner loop
                            i <= i + 4'd1;
                            state <= OUTER_LOOP;
                        end
                    end else begin
                        // Inner loop complete
                        i <= i + 4'd1;
                        state <= OUTER_LOOP;
                    end
                end

                UPDATE_MPI: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        // Update mpis[j] if current_prod is larger
                        if (current_prod > mpis[j]) begin
                            mpis[j] <= current_prod;
                        end
                        j <= j + 4'd1;
                        state <= INNER_LOOP;
                    end
                end

                FIND_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else if (i < len) begin
                        // Find max value in mpis array
                        if (mpis[i] > result) begin
                            result <= mpis[i];
                        end
                        i <= i + 4'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule