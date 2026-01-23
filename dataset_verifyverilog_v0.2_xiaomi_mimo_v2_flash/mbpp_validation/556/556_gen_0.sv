module odd_xor_pairs (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_i,
    input wire [2:0] idx,
    input wire valid,
    input wire done,
    output reg [7:0] result,
    output reg ready
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COLLECTING = 2'b01;
    localparam COMPUTING = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [2:0] odd_count;
    reg [2:0] even_count;
    reg [2:0] next_odd_count;
    reg [2:0] next_even_count;
    reg [7:0] next_result;
    reg next_ready;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            odd_count <= 3'b0;
            even_count <= 3'b0;
            result <= 8'b0;
            ready <= 1'b0;
        end else begin
            state <= next_state;
            odd_count <= next_odd_count;
            even_count <= next_even_count;
            result <= next_result;
            ready <= next_ready;
        end
    end

    // Combinational next state logic
    always @(*) begin
        // Defaults
        next_state = state;
        next_odd_count = odd_count;
        next_even_count = even_count;
        next_result = result;
        next_ready = ready;

        case (state)
            IDLE: begin
                if (valid) begin
                    next_state = COLLECTING;
                    next_odd_count = 3'b0;
                    next_even_count = 3'b0;
                    if (data_i[0]) begin
                        next_odd_count = 3'b1;
                    end else begin
                        next_even_count = 3'b1;
                    end
                    next_ready = 1'b0;
                end
            end

            COLLECTING: begin
                if (valid) begin
                    if (data_i[0]) begin
                        next_odd_count = odd_count + 1'b1;
                    end else begin
                        next_even_count = even_count + 1'b1;
                    end
                end
                if (done) begin
                    next_state = COMPUTING;
                end
            end

            COMPUTING: begin
                // Combinational multiplication
                // odd_count * even_count
                // Max 4*4=16, fits in 8 bits
                next_result = odd_count * even_count;
                next_state = DONE;
                next_ready = 1'b1;
            end

            DONE: begin
                // Hold result
                next_state = DONE;
                next_ready = 1'b1;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule