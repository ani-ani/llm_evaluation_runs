module tuple_size(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_elements,
    input [7:0] element_widths [0:7],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] count, next_count; // Iterator 0-7
    reg [15:0] acc_sum, next_acc_sum; // Accumulator
    reg [3:0] num_elements_reg, next_num_elements_reg; // Store input for duration

    // State Register & Sync Reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            acc_sum <= 16'd0;
            num_elements_reg <= 4'd0;
        end else begin
            state <= next_state;
            count <= next_count;
            acc_sum <= next_acc_sum;
            num_elements_reg <= next_num_elements_reg;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_count = count;
        next_acc_sum = acc_sum;
        next_num_elements_reg = num_elements_reg;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    next_count = 4'd0;
                    next_acc_sum = 16'd20; // Initialize with overhead
                    next_num_elements_reg = num_elements;
                end
            end

            PROCESSING: begin
                // Add current element width if index < num_elements
                if (count < num_elements_reg) begin
                    next_acc_sum = acc_sum + element_widths[count];
                end
                
                if (count < 4'd7) begin
                    next_count = count + 4'd1;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                // Hold state until reset
                if (!rst_n) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(*) begin
        if (state == DONE) begin
            done = 1'b1;
            result = acc_sum;
        end else begin
            done = 1'b0;
            result = 16'd0;
        end
    end

endmodule