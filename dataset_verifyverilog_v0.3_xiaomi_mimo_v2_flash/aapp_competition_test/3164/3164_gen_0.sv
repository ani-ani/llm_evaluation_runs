module longest_exactly_twice(
    input [15:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [3:0] N,
    output reg [7:0] max_length
);

    // Create an array for easier access
    wire [15:0] arr [0:7];
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;

    // States for the FSM
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_L = 3'd1;
    localparam [2:0] INIT_START = 3'd2;
    localparam [2:0] CHECK_I = 3'd3;
    localparam [2:0] CHECK_J = 3'd4;
    localparam [2:0] UPDATE = 3'd5;
    localparam [2:0] FINISHED = 3'd6;

    // Control registers
    reg [2:0] state, next_state;
    reg [7:0] l_reg;
    reg [7:0] start_reg;
    reg [7:0] i_reg;
    reg [7:0] j_reg;
    reg valid_flag;
    reg [15:0] count;
    reg [15:0] target_val;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = INIT_L;
            INIT_L: begin
                if (l_reg < 2) next_state = FINISHED;
                else if (l_reg > N) next_state = INIT_L;
                else next_state = INIT_START;
            end
            INIT_START: begin
                if (start_reg > N - l_reg) next_state = UPDATE;
                else next_state = CHECK_I;
            end
            CHECK_I: begin
                if (i_reg >= l_reg) next_state = UPDATE;
                else next_state = CHECK_J;
            end
            CHECK_J: begin
                if (j_reg >= l_reg) begin
                    if (count != 16'd2) next_state = UPDATE;
                    else next_state = CHECK_I;
                end else begin
                    next_state = CHECK_J;
                end
            end
            UPDATE: next_state = INIT_L;
            FINISHED: next_state = FINISHED;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_length <= 8'd0;
            l_reg <= 8'd8;
            start_reg <= 8'd0;
            i_reg <= 8'd0;
            j_reg <= 8'd0;
            valid_flag <= 1'b1;
            count <= 16'd0;
            target_val <= 16'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    max_length <= 8'd0;
                    l_reg <= 8'd8;
                end

                INIT_L: begin
                    if (l_reg < 2) begin
                        // Done
                    end else if (l_reg > N) begin
                        l_reg <= l_reg - 8'd2;
                    end else begin
                        start_reg <= 8'd0;
                    end
                end

                INIT_START: begin
                    if (start_reg > N - l_reg) begin
                        // Move to next l
                        l_reg <= l_reg - 8'd2;
                    end else begin
                        i_reg <= 8'd0;
                        valid_flag <= 1'b1;
                    end
                end

                CHECK_I: begin
                    if (i_reg >= l_reg) begin
                        // Valid segment found
                        if (valid_flag && l_reg > max_length) begin
                            max_length <= l_reg;
                        end
                        start_reg <= start_reg + 8'd1;
                    end else begin
                        j_reg <= 8'd0;
                        count <= 16'd0;
                        target_val <= arr[start_reg + i_reg];
                    end
                end

                CHECK_J: begin
                    if (j_reg < l_reg) begin
                        if (arr[start_reg + j_reg] == target_val) begin
                            count <= count + 16'd1;
                        end
                        j_reg <= j_reg + 8'd1;
                    end else begin
                        if (count != 16'd2) begin
                            valid_flag <= 1'b0;
                        end
                        i_reg <= i_reg + 8'd1;
                    end
                end

                UPDATE: begin
                    // This state handles moving to next iteration
                    if (valid_flag && l_reg > max_length) begin
                        max_length <= l_reg;
                    end
                    start_reg <= start_reg + 8'd1;
                end

                FINISHED: begin
                    // Hold result
                end

                default: begin
                    state <= IDLE;
                    max_length <= 8'd0;
                end
            endcase
        end
    end

endmodule