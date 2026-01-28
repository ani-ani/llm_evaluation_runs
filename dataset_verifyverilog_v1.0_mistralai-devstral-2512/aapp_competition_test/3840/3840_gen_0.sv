module min_moves_chests(
    input clk,
    input rst_n,
    input start,
    input [9:0] a_1_to_a_n [0:99],
    input [6:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_VALID = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal buffer for chest values
    reg [9:0] buffer [0:99];
    reg [15:0] moves;
    reg [6:0] i;
    reg [6:0] p;
    reg [9:0] child_max;
    reg [9:0] parent_new;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd65535;
            done <= 1'b0;
            cycle_count <= 8'd0;
            moves <= 16'd0;
            i <= 7'd0;
            p <= 7'd0;
            child_max <= 10'd0;
            parent_new <= 10'd0;
            // Initialize buffer
            integer j;
            for (j = 0; j < 100; j = j + 1) begin
                buffer[j] <= 10'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK_VALID;
                    end
                end

                CHECK_VALID: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (n == 7'd1 || n[0] == 1'b0) begin
                        // Invalid case: n is 1 or even
                        result <= 16'd65535;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // Valid case: n is odd and >1
                        // Copy input to buffer
                        integer k;
                        for (k = 0; k < 100; k = k + 1) begin
                            if (k < n) begin
                                buffer[k] <= a_1_to_a_n[k];
                            end else begin
                                buffer[k] <= 10'd0;
                            end
                        end
                        moves <= 16'd0;
                        i <= n - 7'd2; // Start from n-2 (last odd index)
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i >= 7'd2) begin
                        // Process current pair
                        if (buffer[i] > buffer[i - 7'd1]) begin
                            child_max <= buffer[i];
                        end else begin
                            child_max <= buffer[i - 7'd1];
                        end
                        moves <= moves + child_max;
                        p <= i / 7'd2; // Integer division
                        parent_new <= buffer[p] - child_max;
                        if (parent_new[9]) begin // Check if negative
                            parent_new <= 10'd0;
                        end
                        buffer[p] <= parent_new;
                        buffer[i] <= 10'd0;
                        buffer[i - 7'd1] <= 10'd0;
                        i <= i - 7'd2; // Step down by 2
                    end else begin
                        // Final step: add remaining coins in root
                        moves <= moves + buffer[7'd1];
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= moves;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule