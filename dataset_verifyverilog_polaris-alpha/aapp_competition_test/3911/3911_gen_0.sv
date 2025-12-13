module slime_merger(
    input clk,
    input rst_n,
    input [2:0] n,
    input start,
    output reg [2:0] elem_0,
    output reg [2:0] elem_1,
    output reg [2:0] elem_2,
    output reg [2:0] elem_3,
    output reg done
);

    // Internal stack: can hold up to 8 elements, 3 bits each
    reg [2:0] stack [0:7];
    reg [3:0] sp;          // stack pointer: number of elements in stack (0-8)
    reg [2:0] cnt;         // counts remaining slimes to process
    reg busy;              // indicates processing in progress

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous active-low reset
            elem_0 <= 3'd0;
            elem_1 <= 3'd0;
            elem_2 <= 3'd0;
            elem_3 <= 3'd0;
            done   <= 1'b0;
            busy   <= 1'b0;
            sp     <= 4'd0;
            cnt    <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                stack[i] <= 3'd0;
            end
        end else begin
            // Default
            done <= 1'b0;

            // Start new operation (only if not currently busy)
            if (start && !busy && (n != 3'd0)) begin
                // Initialize stack with first slime (value 1)
                stack[0] <= 3'd1;
                for (i = 1; i < 8; i = i + 1) begin
                    stack[i] <= 3'd0;
                end
                sp   <= 4'd1;           // one element in stack
                cnt  <= n - 3'd1;       // remaining slimes to process
                busy <= 1'b1;
            end else if (busy) begin
                if (cnt != 3'd0) begin
                    // Process one new slime (value 1)
                    // Push new slime at stack[sp]
                    stack[sp] <= 3'd1;
                    sp <= sp + 4'd1;

                    // Perform merges combinationally within this cycle
                    // using temporary variables
                    reg [2:0] tmp_stack [0:7];
                    reg [3:0] tmp_sp;
                    reg merge_done;

                    // Initialize temporaries with post-push state
                    for (i = 0; i < 8; i = i + 1) begin
                        tmp_stack[i] = stack[i];
                    end
                    tmp_sp = sp + 4'd1; // reflecting the push above

                    // Merge loop: keep merging last two elements while equal
                    merge_done = 1'b0;
                    while (!merge_done && (tmp_sp > 4'd1)) begin
                        if (tmp_stack[tmp_sp-1] == tmp_stack[tmp_sp-2]) begin
                            // Merge
                            tmp_stack[tmp_sp-2] = tmp_stack[tmp_sp-2] + 3'd1;
                            tmp_sp = tmp_sp - 4'd1;
                        end else begin
                            merge_done = 1'b1;
                        end
                    end

                    // Write merged result back to main stack
                    for (i = 0; i < 8; i = i + 1) begin
                        stack[i] <= (i < tmp_sp) ? tmp_stack[i] : 3'd0;
                    end
                    sp  <= tmp_sp;
                    cnt <= cnt - 3'd1;

                    // If that was the last slime, finalize on next branch
                    if (cnt == 3'd1) begin
                        // Next cycle we will declare done after this insertion
                    end
                end else begin
                    // All slimes processed: output stack and signal done
                    elem_0 <= (sp > 4'd0) ? stack[0] : 3'd0;
                    elem_1 <= (sp > 4'd1) ? stack[1] : 3'd0;
                    elem_2 <= (sp > 4'd2) ? stack[2] : 3'd0;
                    elem_3 <= (sp > 4'd3) ? stack[3] : 3'd0;
                    done   <= 1'b1;
                    busy   <= 1'b0;
                end
            end
        end
    end

endmodule