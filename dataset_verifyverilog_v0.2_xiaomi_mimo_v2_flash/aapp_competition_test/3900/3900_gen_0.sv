module suspect_selection (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [2:0] p,
    input wire [23:0] x_arr,
    input wire [23:0] y_arr,
    output reg [5:0] result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam ITERATE_PAIRS = 2'b01;
    localparam CALCULATE_AGREEMENT = 2'b10;
    localparam FINALIZE = 2'b11;

    reg [1:0] state;
    reg [2:0] u;
    reg [2:0] v;
    reg [2:0] coder_idx;
    reg [2:0] agreement_count;
    reg [5:0] valid_pairs;

    wire [2:0] current_x;
    wire [2:0] current_y;

    // Slice the 24-bit packed arrays into 3-bit vectors
    assign current_x = x_arr[coder_idx*3 +: 3];
    assign current_y = y_arr[coder_idx*3 +: 3];

    // State Transition and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            u <= 0;
            v <= 0;
            coder_idx <= 0;
            agreement_count <= 0;
            valid_pairs <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= ITERATE_PAIRS;
                        u <= 3'b000;
                        v <= 3'b001;
                        valid_pairs <= 6'b000000;
                    end
                end

                ITERATE_PAIRS: begin
                    if (u < n) begin
                        state <= CALCULATE_AGREEMENT;
                        coder_idx <= 0;
                        agreement_count <= 0;
                    end else begin
                        state <= FINALIZE;
                        result <= valid_pairs;
                    end
                end

                CALCULATE_AGREEMENT: begin
                    if (coder_idx < n) begin
                        if (current_x == u || current_y == u || current_x == v || current_y == v) begin
                            agreement_count <= agreement_count + 1;
                        end
                        coder_idx <= coder_idx + 1;
                    end else begin
                        if (agreement_count >= p) begin
                            valid_pairs <= valid_pairs + 1;
                        end
                        if (v < n - 1) begin
                            v <= v + 1;
                            state <= ITERATE_PAIRS;
                        end else begin
                            u <= u + 1;
                            if (u + 2 < n) begin
                                v <= u + 2;
                            end else begin
                                v <= u + 1;
                            end
                            state <= ITERATE_PAIRS;
                        end
                    end
                end

                FINALIZE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule