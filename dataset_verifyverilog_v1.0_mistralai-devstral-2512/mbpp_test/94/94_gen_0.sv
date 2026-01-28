module tuple_min_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire data_valid,
    input wire [63:0] tuple_str [0:15],
    input wire [15:0] tuple_val [0:15],
    input wire [4:0] valid_tuples,
    output reg [63:0] result_str,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] UPDATE  = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [15:0] current_min_val;
    reg [3:0] current_min_idx;
    reg [3:0] tuple_idx;
    reg [15:0] current_val;

    // Timeout constant
    localparam [7:0] MAX_CYCLES = 8'd256;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            current_min_val <= 16'd65535;
            current_min_idx <= 4'd0;
            tuple_idx <= 4'd0;
            result_str <= 64'd0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && data_valid) begin
                        if (valid_tuples == 5'd0) begin
                            error <= 1'b1;
                            next_state <= IDLE;
                        end else begin
                            next_state <= LOAD;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    current_min_val <= 16'd65535;
                    current_min_idx <= 4'd0;
                    tuple_idx <= 4'd0;
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    current_val <= tuple_val[tuple_idx];
                    if (current_val < current_min_val) begin
                        next_state <= UPDATE;
                    end else begin
                        if (tuple_idx == valid_tuples - 1) begin
                            next_state <= DONE;
                        end else begin
                            tuple_idx <= tuple_idx + 4'd1;
                            next_state <= COMPARE;
                        end
                    end
                end

                UPDATE: begin
                    current_min_val <= current_val;
                    current_min_idx <= tuple_idx;
                    if (tuple_idx == valid_tuples - 1) begin
                        next_state <= DONE;
                    end else begin
                        tuple_idx <= tuple_idx + 4'd1;
                        next_state <= COMPARE;
                    end
                end

                DONE: begin
                    result_str <= tuple_str[current_min_idx];
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Timeout check
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main FSM
        end else begin
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                cycle_count <= 8'd0;
                error <= 1'b1;
                done <= 1'b0;
            end
        end
    end

endmodule