module phone_network_detector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N_in,
    input wire [31:0] M_in,
    input wire [31:0] P_i [0:255],
    input wire [31:0] C_i [0:255],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] LOAD      = 4'd1;
    localparam [3:0] SORT_INIT = 4'd2;
    localparam [3:0] SORT_OUTER = 4'd3;
    localparam [3:0] SORT_INNER = 4'd4;
    localparam [3:0] FIND_MAX   = 4'd5;
    localparam [3:0] DONE_STATE = 4'd6;

    reg [3:0] state, next_state;
    reg [7:0] N_reg;
    reg [7:0] i, j, k;
    reg [31:0] P_sorted [0:255];
    reg [31:0] C_sorted [0:255];
    reg [31:0] temp_p, temp_c;
    reg [31:0] max_val;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd2000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            N_reg <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            temp_p <= 32'd0;
            temp_c <= 32'd0;
            max_val <= 32'd0;
            cycle_count <= 32'd0;
            // Initialize arrays
            for (int idx = 0; idx < 256; idx = idx + 1) begin
                P_sorted[idx] <= 32'd0;
                C_sorted[idx] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        state <= LOAD;
                        N_reg <= (N_in > 8'd256) ? 8'd256 : N_in;
                        i <= 8'd0;
                    end
                end

                LOAD: begin
                    if (i < N_reg) begin
                        P_sorted[i] <= P_i[i];
                        C_sorted[i] <= C_i[i];
                        i <= i + 8'd1;
                    end else begin
                        state <= SORT_INIT;
                        i <= 8'd0;
                        j <= 8'd0;
                    end
                end

                SORT_INIT: begin
                    i <= 8'd0;
                    state <= SORT_OUTER;
                end

                SORT_OUTER: begin
                    cycle_count <= cycle_count + 32'd1;
                    if (i < N_reg - 8'd1) begin
                        j <= 8'd0;
                        state <= SORT_INNER;
                    end else begin
                        state <= FIND_MAX;
                        max_val <= 32'd0;
                        i <= 8'd0;
                    end
                end

                SORT_INNER: begin
                    if (j < N_reg - 8'd1 - i) begin
                        if (P_sorted[j] > P_sorted[j + 8'd1]) begin
                            temp_p <= P_sorted[j];
                            P_sorted[j] <= P_sorted[j + 8'd1];
                            P_sorted[j + 8'd1] <= temp_p;
                            temp_c <= C_sorted[j];
                            C_sorted[j] <= C_sorted[j + 8'd1];
                            C_sorted[j + 8'd1] <= temp_c;
                        end
                        j <= j + 8'd1;
                    end else begin
                        i <= i + 8'd1;
                        state <= SORT_OUTER;
                    end
                end

                FIND_MAX: begin
                    if (i < N_reg) begin
                        if (C_sorted[i] > max_val) begin
                            max_val <= C_sorted[i];
                        end
                        i <= i + 8'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= max_val;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule