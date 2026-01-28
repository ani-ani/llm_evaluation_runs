module unique_element_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [3:0] counter;
    reg [7:0] reference;
    reg [7:0] current;
    reg match;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            counter <= 4'd0;
            reference <= 8'd0;
            current <= 8'd0;
            match <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPARE;
                        counter <= 4'd0;
                        reference <= arr[0];
                        match <= 1'b1;
                    end
                end
                
                COMPARE: begin
                    if (len == 4'd0 || len == 4'd1) begin
                        result <= 1'b1;
                        state <= FINISH;
                    end else begin
                        current <= arr[counter];
                        if (current != reference) begin
                            match <= 1'b0;
                        end
                        
                        if (counter == len - 4'd1 || !match) begin
                            result <= match;
                            state <= FINISH;
                        end else begin
                            counter <= counter + 4'd1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule