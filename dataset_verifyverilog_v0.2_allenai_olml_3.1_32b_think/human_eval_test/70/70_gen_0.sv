module strange_sort (
    input clk,
    input rst_n,
    input [7:0] data_in,
    input valid_in,
    input start,
    output reg [7:0] data_out,
    output reg valid_out,
    output reg done
);

    // Parameters
    localparam N = 8;

    // Registers
    reg [7:0] data_buffer [N-1:0];
    reg [N-1:0] mask;
    reg [7:0] sorted_values [N-1:0];
    reg [3:0] count;
    reg [2:0] select_count;
    reg [1:0] phase;
    reg [2:0] output_ptr;
    reg [3:0] state;
    reg [7:0] data_out_reg;
    reg valid_out_reg;
    reg done_reg;
    reg start_reg;
    reg start_prev;

    // Combinatorial logic for min/max
    wire [7:0] min_val_w, max_val_w;
    wire [N-1:0] min_idx_w, max_idx_w;
    wire min_found, max_found;

    always @(*) begin
        min_val_w = 32'd150;
        max_val_w = 32'd-151;
        min_idx_w = N; // Invalid index
        max_idx_w = N;
        min_found = 1'b0;
        max_found = 1'b0;

        genvar i;
        generate
            for (i=0; i<N; i++) begin: find_min_max
                if (mask[i]) begin
                    if (data_buffer[i] < min_val_w) begin
                        min_val_w = data_buffer[i];
                        min_idx_w = i;
                        min_found = 1'b1;
                    end
                    if (data_buffer[i] > max_val_w) begin
                        max_val_w = data_buffer[i];
                        max_idx_w = i;
                        max_found = 1'b1;
                    end
                end
            end
        endgenerate
    end

    // Registered start signal
    always @(posedge clk) begin
        if (!rst_n) begin
            start_reg <= 1'b0;
            start_prev <= 1'b0;
        end else begin
            start_reg <= start;
            start_prev <= start_reg;
        end
    end

    // Main state machine
    always @(posedge clk) begin
        if (!rst_n) begin
            data_buffer <= {N{{8'b0}}};
            mask <= {N{{1'b0}}};
            count <= 4'd0;
            select_count <= 3'd0;
            phase <= 2'd0;
            output_ptr <= 3'd0;
            state <= 4'd0;
            data_out_reg <= 8'b0;
            valid_out_reg <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            if (state == 4'd0) begin // IDLE
                if (start_reg && !start_prev) begin // rising edge of start
                    state <= 4'd1; // move to LOADING
                end
            end else if (state == 4'd1) begin // LOADING
                if (start_reg && !start_prev) begin // rising edge of start
                    if (count > 4'd0) begin
                        state <= 4'd2; // move to SORTING
                    end
                end else if (valid_in) begin
                    if (count < N) begin
                        data_buffer[count] <= data_in;
                        mask[count] <= 1'b1;
                        count <= count + 1;
                    end
                end
            end else if (state == 4'd2) begin // SORTING
                if (select_count < count) begin
                    if (phase == 2'd0) begin // find min
                        if (min_found) begin
                            sorted_values[select_count] <= min_val_w;
                            mask[min_idx_w] <= 1'b0;
                            select_count <= select_count + 1;
                            phase <= 1'd1;
                        end
                    end else begin // find max
                        if (max_found) begin
                            sorted_values[select_count] <= max_val_w;
                            mask[max_idx_w] <= 1'b0;
                            select_count <= select_count + 1;
                            phase <= 1'd0;
                        end
                    end
                end else begin
                    state <= 4'd3; // move to OUTPUT
                end
            end else if (state == 4'd3) begin // OUTPUT
                if (output_ptr < count) begin
                    data_out_reg <= sorted_values[output_ptr];
                    valid_out_reg <= 1'b1;
                    output_ptr <= output_ptr + 1;
                end else begin
                    done_reg <= 1'b1;
                    state <= 4'd4; // DONE
                end
            end
        end
    end

    // Assign outputs
    assign data_out = data_out_reg;
    assign valid_out = valid_out_reg;
    assign done = done_reg;

endmodule