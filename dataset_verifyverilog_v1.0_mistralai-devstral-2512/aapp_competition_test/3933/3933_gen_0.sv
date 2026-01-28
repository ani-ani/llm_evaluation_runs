module temp_predictor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [11:0] temp_data,
    input wire temp_valid,
    input wire [6:0] n_in,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_FIRST = 3'd1;
    localparam [2:0] READ_SECOND = 3'd2;
    localparam [2:0] VERIFY_LOOP = 3'd3;
    localparam [2:0] CALCULATE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [11:0] t0, t1, current_temp, prev_temp;
    reg [12:0] diff;  // 13-bit signed difference
    reg is_arithmetic;
    reg [6:0] counter;
    reg [6:0] n_reg;
    reg [15:0] result_reg;

    // Default assignments
    assign ready = (state == IDLE) ? 1'b1 : 1'b0;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 7'd0;
            n_reg <= 7'd0;
            t0 <= 12'd0;
            t1 <= 12'd0;
            current_temp <= 12'd0;
            prev_temp <= 12'd0;
            diff <= 13'd0;
            is_arithmetic <= 1'b1;
            result_reg <= 16'd0;
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
                    next_state = READ_FIRST;
                end
            end

            READ_FIRST: begin
                if (temp_valid) begin
                    next_state = READ_SECOND;
                end
            end

            READ_SECOND: begin
                if (temp_valid) begin
                    if (n_reg > 2) begin
                        next_state = VERIFY_LOOP;
                    end else begin
                        next_state = CALCULATE;
                    end
                end
            end

            VERIFY_LOOP: begin
                if (temp_valid) begin
                    counter = counter + 7'd1;
                    if (counter == n_reg - 2) begin
                        next_state = CALCULATE;
                    end
                end
            end

            CALCULATE: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Data processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset above
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        counter <= 7'd0;
                        is_arithmetic <= 1'b1;
                    end
                end

                READ_FIRST: begin
                    if (temp_valid) begin
                        t0 <= temp_data;
                        prev_temp <= temp_data;
                    end
                end

                READ_SECOND: begin
                    if (temp_valid) begin
                        t1 <= temp_data;
                        diff <= {1'b0, temp_data} - {1'b0, t0};
                        prev_temp <= temp_data;
                    end
                end

                VERIFY_LOOP: begin
                    if (temp_valid) begin
                        current_temp <= temp_data;
                        if (is_arithmetic) begin
                            if ({1'b0, temp_data} - {1'b0, prev_temp} != diff) begin
                                is_arithmetic <= 1'b0;
                            end
                        end
                        prev_temp <= temp_data;
                    end
                end

                CALCULATE: begin
                    if (is_arithmetic) begin
                        result_reg <= {1'b0, prev_temp} + diff;
                    end else begin
                        result_reg <= {4'b0, prev_temp};
                    end
                end

                DONE_STATE: begin
                    result <= result_reg;
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule