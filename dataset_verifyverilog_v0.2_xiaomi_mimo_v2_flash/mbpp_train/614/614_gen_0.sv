module cumulative_sum(
    input clk,
    input rst_n,
    input start,
    input [7:0] tuple1_elem0,
    input [7:0] tuple1_elem1,
    input [7:0] tuple2_elem0,
    input [7:0] tuple2_elem1,
    input [7:0] tuple2_elem2,
    input [7:0] tuple3_elem0,
    input [7:0] tuple3_elem1,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE  = 9'b000000001;
    localparam ADD1  = 9'b000000010;
    localparam ADD2  = 9'b000000100;
    localparam ADD3  = 9'b000001000;
    localparam ADD4  = 9'b000010000;
    localparam ADD5  = 9'b000100000;
    localparam ADD6  = 9'b001000000;
    localparam ADD7  = 9'b010000000;
    localparam DONE  = 9'b100000000;

    reg [8:0] state;
    reg [8:0] next_state;
    reg [7:0] temp_val;
    reg [15:0] accumulator;
    reg [15:0] next_accumulator;

    // State register and synchronous reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            accumulator <= 16'd0;
        end else begin
            state <= next_state;
            accumulator <= next_accumulator;
        end
    end

    // Next state logic and output logic
    always @(*) begin
        // Default values
        next_state = state;
        next_accumulator = accumulator;
        temp_val = 8'd0;
        result = accumulator;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = ADD1;
                    next_accumulator = 16'd0;
                end
            end

            ADD1: begin
                temp_val = tuple1_elem0;
                next_accumulator = accumulator + temp_val;
                next_state = ADD2;
            end

            ADD2: begin
                temp_val = tuple1_elem1;
                next_accumulator = accumulator + temp_val;
                next_state = ADD3;
            end

            ADD3: begin
                temp_val = tuple2_elem0;
                next_accumulator = accumulator + temp_val;
                next_state = ADD4;
            end

            ADD4: begin
                temp_val = tuple2_elem1;
                next_accumulator = accumulator + temp_val;
                next_state = ADD5;
            end

            ADD5: begin
                temp_val = tuple2_elem2;
                next_accumulator = accumulator + temp_val;
                next_state = ADD6;
            end

            ADD6: begin
                temp_val = tuple3_elem0;
                next_accumulator = accumulator + temp_val;
                next_state = ADD7;
            end

            ADD7: begin
                temp_val = tuple3_elem1;
                next_accumulator = accumulator + temp_val;
                next_state = DONE;
            end

            DONE: begin
                done = 1'b1;
                if (start) begin
                    next_state = ADD1;
                    next_accumulator = 16'd0;
                end else begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
                next_accumulator = 16'd0;
            end
        endcase
    end

endmodule