module max_avg_subseq(
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
    input wire [2:0] K,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] START         = 4'd1;
    localparam [3:0] INIT_I        = 4'd2;
    localparam [3:0] ACCUM         = 4'd3;
    localparam [3:0] COMPARE       = 4'd4;
    localparam [3:0] COMPUTE_RESULT = 4'd5;
    localparam [3:0] DONE_STATE    = 4'd6;

    // Internal registers
    reg [3:0] state;
    reg [7:0] loaded_arr [0:7];
    reg [15:0] best_sum;
    reg [3:0] best_len;
    reg [15:0] current_sum;
    reg [3:0] i;
    reg [3:0] j;
    reg done_reg;
    reg [31:0] result_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            done_reg <= 1'b0;
            result_reg <= 32'd0;
            best_sum <= 16'd0;
            best_len <= 4'd0;
            current_sum <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            cycle_count <= 8'd0;
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                loaded_arr[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= START;
                    end
                end

                START: begin
                    // Latch input array
                    loaded_arr[0] <= arr_0;
                    loaded_arr[1] <= arr_1;
                    loaded_arr[2] <= arr_2;
                    loaded_arr[3] <= arr_3;
                    loaded_arr[4] <= arr_4;
                    loaded_arr[5] <= arr_5;
                    loaded_arr[6] <= arr_6;
                    loaded_arr[7] <= arr_7;
                    best_sum <= 16'd0;
                    best_len <= 4'd0;
                    i <= 4'd0;
                    state <= INIT_I;
                end

                INIT_I: begin
                    j <= i;
                    current_sum <= 16'd0;
                    if (i + K - 1'b1 >= 8'd8) begin
                        state <= COMPUTE_RESULT;
                    end else begin
                        state <= ACCUM;
                    end
                end

                ACCUM: begin
                    current_sum <= current_sum + loaded_arr[j];
                    j <= j + 1'b1;
                    if (j < i + K) begin
                        state <= ACCUM;
                    end else begin
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Cross-multiplication comparison
                    reg [31:0] current_product;
                    reg [31:0] best_product;
                    current_product <= current_sum * (j - i);
                    best_product <= best_sum * best_len;
                    if (current_product > best_product) begin
                        best_sum <= current_sum;
                        best_len <= j - i;
                    end
                    if (j < 8'd8) begin
                        current_sum <= current_sum + loaded_arr[j];
                        j <= j + 1'b1;
                        state <= COMPARE;
                    end else begin
                        i <= i + 1'b1;
                        state <= INIT_I;
                    end
                end

                COMPUTE_RESULT: begin
                    // Compute result = (best_sum * 65536) / best_len
                    reg [47:0] temp_product;
                    temp_product <= best_sum * 48'd65536;
                    result_reg <= temp_product[47:16];
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done_reg <= 1'b1;
                    done <= 1'b1;
                    result <= result_reg;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
            
            // Cycle counter for safety
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 32'd0;
                end
            end
        end
    end

endmodule