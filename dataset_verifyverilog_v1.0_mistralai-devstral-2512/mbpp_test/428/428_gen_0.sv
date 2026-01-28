module ShellSort(
    input clk,
    input rst_n,
    input start,
    input [127:0] data_in,
    output reg [127:0] data_out,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] INIT      = 4'd1;
    localparam [3:0] GAP_LOOP  = 4'd2;
    localparam [3:0] INNER_LOOP = 4'd3;
    localparam [3:0] COMPARE   = 4'd4;
    localparam [3:0] SWAP      = 4'd5;
    localparam [3:0] FINISH    = 4'd6;

    // Register declarations
    reg [3:0] state, next_state;
    reg [3:0] gap;
    reg [3:0] i, j;
    reg [7:0] temp;
    reg [7:0] data_reg [0:15];
    reg [7:0] data_i, data_j;
    reg swap_flag;

    // Initialize data registers from input
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            gap <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp <= 8'd0;
            swap_flag <= 1'b0;
            done <= 1'b0;
            busy <= 1'b0;
            for (k = 0; k < 16; k = k + 1) begin
                data_reg[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    busy <= 1'b1;
                    // Load input data into registers
                    for (k = 0; k < 16; k = k + 1) begin
                        data_reg[k] <= data_in[k*8 +: 8];
                    end
                    gap <= 4'd8; // Initial gap
                    next_state <= GAP_LOOP;
                end

                GAP_LOOP: begin
                    if (gap == 4'd0) begin
                        next_state <= FINISH;
                    end else begin
                        i <= 4'd0;
                        next_state <= INNER_LOOP;
                    end
                end

                INNER_LOOP: begin
                    if (i >= 16 - gap) begin
                        gap <= gap >> 1; // Divide gap by 2
                        next_state <= GAP_LOOP;
                    end else begin
                        j <= i;
                        next_state <= COMPARE;
                    end
                end

                COMPARE: begin
                    data_i <= data_reg[i];
                    data_j <= data_reg[j - gap];
                    if (data_i < data_j) begin
                        swap_flag <= 1'b1;
                        next_state <= SWAP;
                    end else begin
                        swap_flag <= 1'b0;
                        i <= i + 4'd1;
                        next_state <= INNER_LOOP;
                    end
                end

                SWAP: begin
                    if (swap_flag) begin
                        temp <= data_reg[j];
                        data_reg[j] <= data_reg[j - gap];
                        data_reg[j - gap] <= temp;
                        j <= j - gap;
                        if (j >= gap) begin
                            next_state <= COMPARE;
                        end else begin
                            i <= i + 4'd1;
                            next_state <= INNER_LOOP;
                        end
                    end else begin
                        i <= i + 4'd1;
                        next_state <= INNER_LOOP;
                    end
                end

                FINISH: begin
                    // Output sorted data
                    for (k = 0; k < 16; k = k + 1) begin
                        data_out[k*8 +: 8] <= data_reg[k];
                    end
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule