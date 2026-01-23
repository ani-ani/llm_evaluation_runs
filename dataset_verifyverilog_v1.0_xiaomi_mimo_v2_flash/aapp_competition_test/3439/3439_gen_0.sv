module baltic_drain (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] grid_data,
    input wire [1:0] drain_row,
    input wire [1:0] drain_col,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC_LOOP = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] idx;
    reg signed [7:0] grid_reg [0:15];
    reg signed [7:0] drain_alt;
    reg [15:0] sum_reg;
    reg signed [15:0] drain_alt_signed;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            idx <= 4'd0;
            sum_reg <= 16'd0;
            drain_alt <= 8'd0;
            drain_alt_signed <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                grid_reg[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load grid into registers
                        grid_reg[0] <= grid_data[7:0];
                        grid_reg[1] <= grid_data[15:8];
                        grid_reg[2] <= grid_data[23:16];
                        grid_reg[3] <= grid_data[31:24];
                        grid_reg[4] <= grid_data[39:32];
                        grid_reg[5] <= grid_data[47:40];
                        grid_reg[6] <= grid_data[55:48];
                        grid_reg[7] <= grid_data[63:56];
                        grid_reg[8] <= grid_data[71:64];
                        grid_reg[9] <= grid_data[79:72];
                        grid_reg[10] <= grid_data[87:80];
                        grid_reg[11] <= grid_data[95:88];
                        grid_reg[12] <= grid_data[103:96];
                        grid_reg[13] <= grid_data[111:104];
                        grid_reg[14] <= grid_data[119:112];
                        grid_reg[15] <= grid_data[127:120];
                        // Store drain altitude
                        drain_alt <= grid_data[8*(drain_row * 4 + drain_col) +: 8];
                        drain_alt_signed <= {8'd0, grid_data[8*(drain_row * 4 + drain_col) +: 8]};
                        // Initialize
                        sum_reg <= 16'd0;
                        idx <= 4'd0;
                        state <= CALC_LOOP;
                    end
                end

                CALC_LOOP: begin
                    if (idx < 16) begin
                        if (grid_reg[idx] < 8'sd0) begin
                            // Compute drained volume for this cell
                            if ($signed({1'b0, grid_reg[idx]}) > -drain_alt_signed) begin
                                sum_reg <= sum_reg + (-grid_reg[idx]);
                            end else begin
                                sum_reg <= sum_reg + drain_alt;
                            end
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        result <= sum_reg;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule