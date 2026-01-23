module ludic_sieve (input clk, input rst_n, input start, input [5:0] max_value, output reg [5:0] result_index, output reg [5:0] result_value, output reg result_valid, output reg done);

// Internal registers
reg [5:0] mem [63:0];
reg [63:0] valid;
reg [5:0] ludic_numbers [63:0];
reg [6:0] ludic_count;
reg [5:0] current_result_index;
reg [5:0] current_result_value;
reg result_valid_reg;
reg done_reg;
reg [1:0] state;
reg [1:0] next_state;
reg [6:0] init_counter;
reg [6:0] collect_counter;
reg [6:0] output_counter;

always @(posedge clk) begin
    if (!rst_n) begin
        mem <= 64'b0;
        valid <= 64'b0;
        ludic_numbers <= 64'b0;
        ludic_count <= 7'b0;
        current_result_index <= 6'b0;
        current_result_value <= 6'b0;
        result_valid_reg <= 1'b0;
        done_reg <= 1'b0;
        state <= 2'b00;
        next_state <= 2'b00;
        init_counter <= 7'b0;
        output_counter <= 7'b0;
        collect_counter <= 7'b0;
    end else begin
        // Compute next_state
        next_state = state; // Default, but will be overridden

        if (state == 2'b00) begin // IDLE
            if (start == 1'b1) begin
                next_state = 2'b01;
                init_counter <= 7'b0;
            end else begin
                next_state = 2'b00;
            end
        end else if (state == 2'b01) begin // INIT_ARRAY
            if (init_counter < max_value) begin
                mem[init_counter] <= init_counter + 1;
                valid[init_counter] <= 1'b1;
                init_counter <= init_counter + 1;
                next_state = 2'b01;
            end else begin
                init_counter <= 7'b0;
                next_state = 2'b10; // PROCESS_SIEVE
            end
        end else if (state == 2'b10) begin // PROCESS_SIEVE
            if (collect_counter < 64) begin
                if (valid[collect_counter]) begin
                    ludic_numbers[collect_counter] <= mem[collect_counter];
                    ludic_count <= ludic_count + 1;
                end
                collect_counter <= collect_counter + 1;
                next_state = 2'b10;
            end else begin
                collect_counter <= 7'b0;
                next_state = 2'b11; // OUTPUT_RESULTS
            end
        end else if (state == 2'b11) begin // OUTPUT_RESULTS
            if (output_counter < ludic_count) begin
                current_result_index <= output_counter;
                current_result_value <= ludic_numbers[output_counter];
                result_valid_reg <= 1'b1;
                output_counter <= output_counter + 1;
                next_state = 2'b11;
            end else begin
                next_state = 2'b00;
                result_valid_reg <= 1'b0;
                done_reg <= 1'b1;
            end
        end else begin
            next_state = 2'b00;
        }

        state <= next_state;
    end
end

// Assign outputs
assign result_index = current_result_index;
assign result_value = current_result_value;
assign result_valid = result_valid_reg;
assign done = done_reg;

endmodule