module TupleExtractor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [79:0] data_in,
    input wire [1:0] n,
    input wire [1:0] len,
    output reg [7:0] data_out,
    output reg valid_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] EXTRACT = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state, next_state;
    reg [1:0] tuple_idx;
    reg [1:0] cycle_count;
    localparam [1:0] MAX_CYCLES = 2'd3;

    // Combinational extraction logic
    wire [7:0] extracted_data;
    always @(*) begin
        case (n)
            2'd0: extracted_data = data_in[7:0];      // ASCII char
            2'd1: extracted_data = data_in[15:8];     // score1
            2'd2: extracted_data = data_in[23:16];    // score2
            default: extracted_data = 8'd0;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            tuple_idx <= 2'd0;
            cycle_count <= 2'd0;
            data_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_out <= 1'b0;
                    cycle_count <= 2'd0;
                    if (start) begin
                        next_state <= EXTRACT;
                        tuple_idx <= 2'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                EXTRACT: begin
                    cycle_count <= cycle_count + 2'd1;
                    data_out <= extracted_data;
                    valid_out <= 1'b1;

                    // Check if this is the last tuple
                    if (tuple_idx == len - 2'd1 || cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= EXTRACT;
                        tuple_idx <= tuple_idx + 2'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid_out <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    valid_out <= 1'b0;
                end
            endcase
        end
    end

endmodule