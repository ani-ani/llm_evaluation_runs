module CombinationsGenerator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [1:0] symbols [0:2],
    output reg [5:0] tuple_out,
    output reg tuple_valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] GEN = 2'd1;
    localparam [1:0] NEXT = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [1:0] indices [0:2];
    reg [7:0] count;
    reg [7:0] total_combinations;

    // Calculate total combinations based on n
    always @(*) begin
        case (n)
            2'd1: total_combinations = 8'd3;
            2'd2: total_combinations = 8'd6;
            2'd3: total_combinations = 8'd10;
            default: total_combinations = 8'd0;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tuple_valid <= 1'b0;
            done <= 1'b0;
            count <= 8'd0;
            indices[0] <= 2'd0;
            indices[1] <= 2'd0;
            indices[2] <= 2'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = GEN;
                end else begin
                    next_state = IDLE;
                end
            end

            GEN: begin
                next_state = NEXT;
            end

            NEXT: begin
                if (count + 8'd1 >= total_combinations) begin
                    next_state = DONE;
                end else begin
                    next_state = GEN;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Index generation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'd0;
            indices[0] <= 2'd0;
            indices[1] <= 2'd0;
            indices[2] <= 2'd0;
        end else if (state == NEXT && next_state == GEN) begin
            // Increment indices for next combination
            case (n)
                2'd1: begin
                    if (indices[0] < 2'd2) begin
                        indices[0] <= indices[0] + 2'd1;
                    end
                end

                2'd2: begin
                    if (indices[1] < 2'd2) begin
                        indices[1] <= indices[1] + 2'd1;
                    end else begin
                        indices[1] <= 2'd0;
                        if (indices[0] < 2'd2) begin
                            indices[0] <= indices[0] + 2'd1;
                        end
                    end
                end

                2'd3: begin
                    if (indices[2] < 2'd2) begin
                        indices[2] <= indices[2] + 2'd1;
                    end else begin
                        indices[2] <= 2'd0;
                        if (indices[1] < 2'd2) begin
                            indices[1] <= indices[1] + 2'd1;
                        end else begin
                            indices[1] <= 2'd0;
                            if (indices[0] < 2'd2) begin
                                indices[0] <= indices[0] + 2'd1;
                            end
                        end
                    end
                end
            endcase
            count <= count + 8'd1;
        end
    end

    // Output logic
    always @(*) begin
        tuple_valid = 1'b0;
        done = 1'b0;
        tuple_out = 6'd0;

        case (state)
            GEN: begin
                tuple_valid = 1'b1;
                case (n)
                    2'd1: tuple_out = {4'd0, symbols[indices[0]]};
                    2'd2: tuple_out = {2'd0, symbols[indices[1]], symbols[indices[0]]};
                    2'd3: tuple_out = {symbols[indices[2]], symbols[indices[1]], symbols[indices[0]]};
                endcase
            end

            DONE: begin
                done = 1'b1;
            end
        endcase
    end

endmodule