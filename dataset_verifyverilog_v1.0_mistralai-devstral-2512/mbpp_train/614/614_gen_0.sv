module cumulative_sum(
    input clk,
    input rst_n,
    input start,
    input [1:0] tuple_count,
    input [2:0] tuple_lengths [0:2],
    input [7:0] values [0:11],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD_COUNT    = 3'd1;
    localparam [2:0] READ_LENGTH   = 3'd2;
    localparam [2:0] SUM_VALUES    = 3'd3;
    localparam [2:0] WRITE_RESULT  = 3'd4;

    reg [2:0] state, next_state;
    reg [1:0] tuple_idx;
    reg [1:0] elem_idx;
    reg [15:0] sum_accum;
    reg [2:0] current_length;
    reg [7:0] current_value;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            tuple_idx <= 2'd0;
            elem_idx <= 2'd0;
            sum_accum <= 16'd0;
            current_length <= 3'd0;
            current_value <= 8'd0;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD_COUNT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    tuple_idx <= 2'd0;
                    sum_accum <= 16'd0;
                    next_state <= READ_LENGTH;
                end

                READ_LENGTH: begin
                    cycle_count <= cycle_count + 8'd1;
                    current_length <= tuple_lengths[tuple_idx];
                    elem_idx <= 2'd0;
                    if (current_length == 3'd0) begin
                        next_state <= WRITE_RESULT;
                    end else begin
                        next_state <= SUM_VALUES;
                    end
                end

                SUM_VALUES: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Calculate flat index: tuple_idx*4 + elem_idx
                    current_value <= values[tuple_idx*4 + elem_idx];
                    sum_accum <= sum_accum + current_value;
                    
                    elem_idx <= elem_idx + 2'd1;
                    if (elem_idx == current_length) begin
                        tuple_idx <= tuple_idx + 2'd1;
                        if (tuple_idx == tuple_count) begin
                            next_state <= WRITE_RESULT;
                        end else begin
                            next_state <= READ_LENGTH;
                        end
                    end else begin
                        next_state <= SUM_VALUES;
                    end
                end

                WRITE_RESULT: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= sum_accum;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule