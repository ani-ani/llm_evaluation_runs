module ConsecutiveSubarrayCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] addr_in,
    input wire we,
    input wire [15:0] data_in,
    input wire [15:0] p_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] CALC_IDLE = 3'd2;
    localparam [2:0] CALC_LOOP = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] load_addr;
    reg [15:0] data_mem [0:15];
    reg [15:0] p_reg;
    reg [31:0] prefix_sum [0:16];
    reg [3:0] i_reg, j_reg;
    reg [31:0] count_reg;
    reg [31:0] sub_sum, threshold;
    reg [3:0] len;

    // Load data FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_addr <= 4'd0;
            p_reg <= 16'd0;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                if (load_addr == 4'd15) begin
                    next_state = CALC_IDLE;
                end
            end
            CALC_IDLE: begin
                next_state = CALC_LOOP;
            end
            CALC_LOOP: begin
                if (i_reg == 4'd15 && j_reg == 4'd15) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load data into memory
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_addr <= 4'd0;
            p_reg <= 16'd0;
            for (integer k = 0; k < 16; k = k + 1) begin
                data_mem[k] <= 16'd0;
            end
        end else if (state == LOAD && we) begin
            if (addr_in < 4'd16) begin
                data_mem[addr_in] <= data_in;
                if (addr_in == 4'd0) begin
                    p_reg <= p_in;
                end
            end
        end
    end

    // Compute prefix sums
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prefix_sum[0] <= 32'd0;
            for (integer k = 1; k < 17; k = k + 1) begin
                prefix_sum[k] <= 32'd0;
            end
        end else if (state == CALC_IDLE) begin
            prefix_sum[0] <= 32'd0;
            for (integer k = 1; k < 17; k = k + 1) begin
                prefix_sum[k] <= prefix_sum[k-1] + {16'd0, data_mem[k-1]};
            end
        end
    end

    // Main calculation loop
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            count_reg <= 32'd0;
        end else if (state == CALC_LOOP) begin
            if (j_reg == 4'd15) begin
                i_reg <= i_reg + 4'd1;
                j_reg <= i_reg;
            end else begin
                j_reg <= j_reg + 4'd1;
            end
        end
    end

    // Comparison logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sub_sum <= 32'd0;
            threshold <= 32'd0;
            len <= 4'd0;
        end else if (state == CALC_LOOP) begin
            len <= j_reg - i_reg + 4'd1;
            sub_sum <= prefix_sum[j_reg + 4'd1] - prefix_sum[i_reg];
            threshold <= {16'd0, p_reg} * len;
            if (sub_sum >= threshold) begin
                count_reg <= count_reg + 32'd1;
            end
        end
    end

    // Output result and done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
        end else if (state == FINISH) begin
            result <= count_reg;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule