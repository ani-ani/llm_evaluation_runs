module bracket_fix(
    input clk,
    input rst_n,
    input start,
    input data_in,
    input valid_in,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state, next_state;
    reg [10:0] balance; // 11-bit signed
    reg [9:0] segment_length; // 10-bit unsigned
    reg [15:0] total_cost; // 16-bit unsigned
    reg segment_active;
    reg [9:0] input_count; // 10-bit counter for input length
    reg [9:0] input_index; // 10-bit index for input buffer
    reg [1023:0] input_buffer; // 1024-bit buffer

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            balance <= 11'd0;
            segment_length <= 10'd0;
            total_cost <= 16'd0;
            segment_active <= 1'b0;
            input_count <= 10'd0;
            input_index <= 10'd0;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
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
                    next_state = READ;
                    ready = 1'b0;
                    input_count = 10'd0;
                    input_index = 10'd0;
                    balance = 11'd0;
                    segment_length = 10'd0;
                    total_cost = 16'd0;
                    segment_active = 1'b0;
                end
            end
            READ: begin
                if (valid_in) begin
                    input_buffer[input_index] = data_in;
                    input_index = input_index + 1'b1;
                    input_count = input_count + 1'b1;
                end
                if (input_index == input_count && input_count != 10'd0) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
                ready = 1'b1;
            end
            default: next_state = IDLE;
        endcase
    end

    // Data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            balance <= 11'd0;
            segment_length <= 10'd0;
            total_cost <= 16'd0;
            segment_active <= 1'b0;
        end else if (state == READ && input_index < input_count) begin
            if (input_buffer[input_index] == 1'b0) begin
                balance <= balance + 1'b1;
            end else begin
                balance <= balance - 1'b1;
            end

            if (balance[10] == 1'b1) begin // Negative balance
                if (!segment_active) begin
                    segment_active <= 1'b1;
                    segment_length <= 10'd1;
                end else begin
                    segment_length <= segment_length + 1'b1;
                end
            end else begin
                if (segment_active && balance == 11'd0) begin
                    total_cost <= total_cost + segment_length + 1'b1;
                    segment_active <= 1'b0;
                    segment_length <= 10'd0;
                end
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else if (state == DONE) begin
            if (balance == 11'd0) begin
                result <= total_cost;
            end else begin
                result <= 16'hFFFF;
            end
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Ready signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1;
        end else if (state == IDLE && !start) begin
            ready <= 1'b1;
        end else begin
            ready <= 1'b0;
        end
    end

endmodule