module polar_bear_compress(
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [5:0] q,
    input reg [3:0] op_a_idx [0:35],
    input reg [3:0] op_b_idx [0:35],
    input reg [2:0] op_dest [0:35],
    input reg [2:0] n,
    output reg [23:0] result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam EXPAND = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [2:0] current_length;
    reg [23:0] valid_current [0:5];
    reg [23:0] valid_next [0:5];

    integer i;

    // Combinational logic to calculate next valid set
    always @(*) begin
        // Initialize valid_next to zero
        for (i = 0; i < 6; i = i + 1) begin
            valid_next[i] = 24'd0;
        end

        // Apply reverse operations
        // Sum contributions from all valid operations
        for (i = 0; i < 36; i = i + 1) begin
            if (i < q) begin
                // If we have valid strings starting with op_dest[i],
                // they expand to strings starting with op_a_idx[i]
                valid_next[op_a_idx[i]] = valid_next[op_a_idx[i]] + valid_current[op_dest[i]];
            end
        end
    end

    // Sequential state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 24'd0;
            current_length <= 3'd0;
            for (i = 0; i < 6; i = i + 1) begin
                valid_current[i] <= 24'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize for length 1: only 'a' (index 0) is valid
                    for (i = 0; i < 6; i = i + 1) begin
                        valid_current[i] <= 24'd0;
                    end
                    valid_current[0] <= 24'd1;
                    current_length <= 3'd1;

                    // Check target length
                    if (n == 3'd1) begin
                        state <= DONE;
                    end else begin
                        state <= EXPAND;
                    end
                end

                EXPAND: begin
                    // Update valid strings to next length using combinational logic
                    valid_current <= valid_next;
                    
                    // Check if we reached target length
                    // We just updated valid_current, so new length is current_length + 1
                    if (current_length == n - 1) begin
                        state <= DONE;
                    end else begin
                        current_length <= current_length + 1;
                        state <= EXPAND;
                    end
                end

                DONE: begin
                    // Sum all valid strings of length n
                    result <= valid_current[0] + valid_current[1] + valid_current[2] + 
                              valid_current[3] + valid_current[4] + valid_current[5];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule