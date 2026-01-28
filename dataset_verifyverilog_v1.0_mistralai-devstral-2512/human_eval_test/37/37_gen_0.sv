module even_index_sorter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    output reg signed [7:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Internal registers for even indices
    reg signed [7:0] even_regs [0:7];
    
    // Bubble sort control
    reg [2:0] pass_count;
    reg [2:0] comp_count;
    reg signed [7:0] temp;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            pass_count <= 3'd0;
            comp_count <= 3'd0;
            
            // Initialize all result registers
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end
            
            // Initialize even_regs
            for (i = 0; i < 8; i = i + 1) begin
                even_regs[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Load even indices into even_regs
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        even_regs[i] <= arr[i * 2];
                    end
                    
                    // Pass through odd indices
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i * 2 + 1] <= arr[i * 2 + 1];
                    end
                    
                    // Initialize bubble sort counters
                    pass_count <= 3'd0;
                    comp_count <= 3'd0;
                    next_state <= SORT;
                end
                
                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort implementation
                    if (pass_count < 7) begin
                        if (comp_count < 7 - pass_count) begin
                            // Compare and swap
                            if (even_regs[comp_count] > even_regs[comp_count + 1]) begin
                                temp <= even_regs[comp_count];
                                even_regs[comp_count] <= even_regs[comp_count + 1];
                                even_regs[comp_count + 1] <= temp;
                            end
                            comp_count <= comp_count + 3'd1;
                        end else begin
                            // End of pass
                            comp_count <= 3'd0;
                            pass_count <= pass_count + 3'd1;
                        end
                    end else begin
                        // Sorting complete
                        next_state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Write sorted even indices to result
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i * 2] <= even_regs[i];
                    end
                    
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule